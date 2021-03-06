# Client-side JavaScript, bundled and sent to client.

# Define Minimongo collections to match server/publish.js.
@Classes = new Meteor.Collection "classes"
@Assignments = new Meteor.Collection "assignments"

@online = -> Meteor.status().status is "connected"

# ID of currently selected class
Session.setDefault "class_id", ""

# When editing a class name, ID of the class
Session.setDefault "editing_class", null

# When editing assignment text, ID of the assignment
Session.setDefault "editing_itemname", null

# Forcing assignments to re-render every so often
Session.setDefault "update_interval", Date.now()
Meteor.setInterval (-> Session.set "update_interval", Date.now()), 500

# Subscribe to "classes" collection on startup.
# Select a class once data has arrived.
classesHandle = Meteor.subscribe "classes", ->
    Router?.setList ""
    Offline.save()

Meteor.setTimeout (-> Router?.setList("")), 20

Meteor.subscribe "assignments", ->
    Offline.save()

Deps.autorun ->
    if !Meteor.userId()?
        Router?.setList("")

Deps.autorun ->
    if Meteor.user()?.profile?
        if not Meteor.user().profile.onboarded
            Meteor.call "onboardMe", new Date().getTimezoneOffset(), ->
                Meteor.subscribe "assignments"
                Offline.save()

# Helpers for in-place editing #

# Returns an event map that handles the "return" and "escape" keys
# on a text input (given by selector) and interprets them
# as "ok" or "cancel".
okCancelEvents = (selector, callbacks) ->
    ok = callbacks.ok || ->
    cancel = callbacks.cancel || ->
    dirty = callbacks.dirty || ->
    blur = callbacks.blur || ->

    events = {}
    events["keyup #{selector}, keydown #{selector}, focusout #{selector}"] =
        (evt) ->
            if evt.type is "keydown" and evt.which is 27
                # escape = cancel
                cancel.call(this, evt)
                blur.call(this, evt)
            else if evt.type is "keyup"
                if evt.which is 13
                    # return/enter = ok/submit if non-empty
                    value = String(evt.target.value || "")
                    ok.call(this, value, evt)
                else
                    value = String(evt.target.value || "")
                    dirty.call(this, value, evt)
            else if evt.type is "focusout"
                blur.call(this, evt)
    return events

activateInput = (input) ->
    input.focus()
    input.select()

Template.contents.helpers
    showEverything: ->
        return true if Meteor.userId()?
        return true if !online
        return false

# Classes #

disableTimeFields = ->
    for dow in (DateOMatic.getDowName(n).toLowerCase() for n in [0..6])
        $(".#{dow} input[type='time']").prop("disabled", not $(".#{dow} input[type='checkbox']").prop("checked"))

Template.classes.helpers
    classes: ->
        # Fake dependency on update_interval to update periodically.
        Meteor.extra_garbage_of_tomfoolery = Session.get "update_interval"

        classes = Offline.smart.classes().find({}).fetch()
        sortIterator = (oneClass) ->
            return oneClass.name unless oneClass.schedule?
            [sun, mon, tue, wed, thu, fri, sat] = oneClass.schedule
            dateStrings = _.compact [
                if sun.enabled
                    "Sunday at #{sun.time}"
                if mon.enabled
                    "Monday at #{mon.time}"
                if tue.enabled
                    "Tuesday at #{tue.time}"
                if wed.enabled
                    "Wednesday at #{wed.time}"
                if thu.enabled
                    "Thursday at #{thu.time}"
                if fri.enabled
                    "Friday at #{fri.time}"
                if sat.enabled
                    "Saturday at #{sat.time}"
            ]
            dates = _.map dateStrings, DateOMatic.parseFuzzyFutureDateAndTime
            deltas = _.map dates, (date) ->
                delta = DateOMatic.msDifferential date
                if delta > 603900000
                    delta = delta - 603900000
                delta
            smallestDelta = Math.min deltas...
            return smallestDelta
        sortedClasses = _.sortBy classes, sortIterator
        return sortedClasses

    fake_all_class_list: -> [_id: ""]

    edit_disabled: -> if online() then "" else "disabled"
    show_edit: -> online()
    class_color: -> @color

Template.new_assignment_box.helpers
    disabled: -> if online() then "" else "disabled"

Template.classes.events
    "mousedown .class": (evt) -> Router.setList(this._id) if @_id?
    "click .class": (evt) -> evt.preventDefault()
    "click .edit": (evt) ->
        Session.set "editing_class", this._id

# Attach events to keydown, keyup, and blur on "New class" input box.
Template.classes.events okCancelEvents "#new-class",
    ok: (text, evt) ->
        if text is "Hamwerk 101"
            Meteor.users.update(Meteor.userId(), {$set: {profile: {onboarded: false}}})
        else
            newClass = {
                name: text
                abbr: text
                user: Meteor.userId()
                color: Please.make_color()
                schedule: [
                    {enabled: no, time: ""}
                    {enabled: no, time: ""}
                    {enabled: no, time: ""}
                    {enabled: no, time: ""}
                    {enabled: no, time: ""}
                    {enabled: no, time: ""}
                    {enabled: no, time: ""}
                ]
            }
            id = Offline.smart.classes().insert newClass, ->
                Meteor.subscribe("assignments")
                Offline.save()
        evt.target.value = ""

Template.classes.helpers
    active: ->
        if Session.equals("class_id", this._id)
            "active"
        else
            ""

# Class Editing #

Template.edit_class_modal.helpers
    name: -> Offline.smart.classes().findOne(Session.get("editing_class"))?.name
    abbr: -> Offline.smart.classes().findOne(Session.get("editing_class"))?.abbr
    class_color: -> Offline.smart.classes().findOne(Session.get("editing_class"))?.color
do ->
    ecmHelpers = {}
    for dow, n in (DateOMatic.getDowName(n).toLowerCase() for n in [0..6])
        do (dow, n) ->
            ecmHelpers["#{dow}Checked"] = ->
                if Offline.smart.classes().findOne(Session.get("editing_class"))?.schedule?[n]?.enabled then "checked" else ""
            ecmHelpers["#{dow}Time"] = ->
                Offline.smart.classes().findOne(Session.get("editing_class"))?.schedule?[n]?.time
    Template.edit_class_modal.helpers ecmHelpers

Template.edit_class_modal.events
    "click .delete": ->
        Meteor.call "nukeClass", Session.get("editing_class"), ->
            Session.set "editing_class", null
            Router?.setList ""
            Offline.save()
    "click .cancel": ->
        Session.set "editing_class", null
    "click .save": ->
        id = Session.get("editing_class")
        name = $("#class-name-input").val()
        abbr = $("#class-abbr-input").val()
        color = $("#class-color-input").val()
        schedule = ({enabled: $(".#{dow} input[type='checkbox']").prop("checked"), time: $(".#{dow} input[type='time']").val()} for dow in (DateOMatic.getDowName(n).toLowerCase() for n in [0..6]))
        Offline.smart.classes().update id, {$set: {name: name, abbr: abbr, color: color, schedule: schedule}}, -> Offline.save()
    "click .random-color": ->
        $("#class-color-input").val(Please.make_color())
    "click input[type='checkbox']": disableTimeFields
    "click form button": (evt) -> evt.preventDefault()

$ ->
    $("#color-help").popover
        content: "Use <a href=\"http://www.crockford.com/wrrrld/color.html\">these words</a> or any other CSS color.
        Press the <i class=\"fa fa-random\"></i> button to generate a random color."
        html: on
        trigger: "focus"
    $("#edit-class").on "shown.bs.modal", disableTimeFields

# New Assignment Box #

Template.new_assignment_box.helpers
    sample: ->
        rand = (min, max) -> Math.floor(Math.random() * (max - min + 1) + min)

        types = [
            -> "today"
            -> "tomorrow"
            -> "#{DateOMatic.getMonthName(rand(0, 11))} #{rand(1, 28)}"
            -> "#{DateOMatic.getMonthName(rand(0, 11))} #{rand(1, 28)}, #{new Date().getFullYear()+1}"
            -> "#{DateOMatic.getDowName(rand(0, 6))}"
            -> "#{DateOMatic.getDowName(rand(0, 6)).slice(0, 3)}"
            -> "#{rand(1, 10)} days from now"
        ]
        task = "read chapter #{rand(1, 15)} due #{_.sample(types)()}"
        if Session.equals("class_id", "")
            "#{_(Offline.smart.classes().find().fetch()).chain().pluck(_.shuffle(['name','abbr'])[0]).shuffle().value()[0]} #{task}"
        else
            "#{task}"

# Assignments #

Template.assignments.events okCancelEvents "#new-assignment",
    ok: (text, evt) ->
        return unless text
        class_id = Session.get("class_id")
        if !class_id
            lowercaseText = text.toLowerCase()
            classes = Offline.smart.classes().find({}, fields: {name: 1, abbr: 1}).fetch()
            guessedClassByName = _.find classes, (thisClass) -> lowercaseText.indexOf(thisClass.name.toLowerCase()) is 0
            guessedClassByAbbr = _.find classes, (thisClass) -> lowercaseText.indexOf(thisClass.abbr?.toLowerCase()) is 0
            if guessedClassByName?
                text = text.slice(guessedClassByName.name.length + 1)
                if text.trim() is ""
                    alert "No assignment specified"
                    $("#new-assignment").parent().addClass("has-error")
                    return
                class_id = guessedClassByName._id
            else if guessedClassByAbbr?
                text = text.slice(guessedClassByAbbr.abbr.length + 1)
                if text.trim() is ""
                    alert "No assignment specified"
                    $("#new-assignment").parent().addClass("has-error")
                    return
                class_id = guessedClassByAbbr._id
            else
                alert "No class specified"
                $("#new-assignment").parent().addClass("has-error")
                return
        newAssignment =
            class_id: class_id
            done: false
            timestamp: (new Date()).getTime()
        dueDateMatch = /(.+) due (.+)/i.exec text
        parsedDate = null
        newAssignment.text = text
        newAssignment.due = DateOMatic.parseFuzzyFutureDate("tomorrow")
        if dueDateMatch?
            parsedDate = DateOMatic.parseFuzzyFutureDate(dueDateMatch[2].toLowerCase())
        if parsedDate isnt null
            newAssignment.text = dueDateMatch[1]
            newAssignment.due = parsedDate
        else if Offline.smart.classes().findOne(class_id).schedule?
            relevantClass = Offline.smart.classes().findOne(class_id)
            if _.any _.pluck relevantClass.schedule, "enabled"
                [sun, mon, tue, wed, thu, fri, sat] = relevantClass.schedule
                dateStrings = _.compact [
                    if sun.enabled
                        "Sunday at #{sun.time}"
                    if mon.enabled
                        "Monday at #{mon.time}"
                    if tue.enabled
                        "Tuesday at #{tue.time}"
                    if wed.enabled
                        "Wednesday at #{wed.time}"
                    if thu.enabled
                        "Thursday at #{thu.time}"
                    if fri.enabled
                        "Friday at #{fri.time}"
                    if sat.enabled
                        "Saturday at #{sat.time}"
                ]
                dates = _.map dateStrings, (dateString) -> {string: dateString, date: DateOMatic.parseFuzzyFutureDateAndTime dateString}
                deltas = _.sortBy dates, (date) -> DateOMatic.msDifferential date.date
                newAssignment.due = deltas[0].date
        Offline.smart.assignments().insert newAssignment, ->
            Offline.save()
        evt.target.value = ""
    dirty: (text, evt) ->
        $("#new-assignment").parent().removeClass("has-error")
        return unless text
        class_id = Session.get("class_id")
        if !class_id
            lowercaseText = text.toLowerCase()
            classes = Offline.smart.classes().find({}, fields: {name: 1, abbr: 1}).fetch()
            guessedClassByName = _.find classes, (thisClass) -> lowercaseText.indexOf(thisClass.name.toLowerCase()) is 0
            guessedClassByAbbr = _.find classes, (thisClass) -> lowercaseText.indexOf(thisClass.abbr?.toLowerCase()) is 0
            if guessedClassByName?
                text = text.slice(guessedClassByName.name.length + 1)
                if text.trim() is ""
                    $("#new-assignment").parent().addClass("has-error")
                    return
                class_id = guessedClassByName._id
            else if guessedClassByAbbr?
                text = text.slice(guessedClassByAbbr.abbr.length + 1)
                if text.trim() is ""
                    $("#new-assignment").parent().addClass("has-error")
                    return
                class_id = guessedClassByAbbr._id
            else
                $("#new-assignment").parent().addClass("has-error")
                return
        dueDateMatch = /(.+) due (.+)/.exec text
        if dueDateMatch?
            parsedDate = DateOMatic.parseFuzzyFutureDate(dueDateMatch[2])
            if parsedDate is null
                # tried and failed to specify a valid date
                $("#new-assignment").parent().addClass("has-error")
                return

div = (a, b) -> (a - a % b) / b

assignmentHelpers =
    assignments: ->
        # Fake dependency on update_interval to update periodically.
        Meteor.extra_garbage_of_tomfoolery = Session.get "update_interval"

        # Determine which assignments to display in main pane,
        # selected based on class_id and tag_filter.
        class_id = Session.get "class_id"

        sel = class_id: class_id
        if class_id is ""
            sel = {}

        return _(Offline.smart.assignments().find(sel).fetch()).chain()
               .sortBy((obj) -> new Date(obj.timestamp).getTime())
               .sortBy((obj) -> new Date(obj.due).getTime())
               .sortBy("done")
               .groupBy("done")
               .pairs()
               .map(([truthiness, list]) -> _.sortBy(list, (obj) ->
                    if truthiness is "true"
                        Math.abs(DateOMatic.msDifferential(new Date(obj.due)))
                    else
                        new Date(obj.due).getTime()
                ))
               .reduce(((memo, list) -> memo.concat(list)), [])
               .value()

    precise_due_date: ->
        DateOMatic.stringify(@due, yes, no, yes)

    editable_due_date: ->
        DateOMatic.stringify(@due, no, yes, yes)

    fuzzy_due_date: ->
        if DateOMatic.isFuture(@due) then "in #{DateOMatic.fuzzyDifferential(@due)}" else "#{DateOMatic.fuzzyDifferential(@due)} ago"

    done_class: ->
        if this.done then "muted" else ""

    done_checkbox: ->
        if this.done then "check-" else ""

    editing: ->
        Session.equals("editing_itemname", this._id)

    class_color: ->
        Offline.smart.classes().findOne(@class_id)?.color

    color_class: ->
        if @done
            return "list-group-item-success"
        msLeft = new Date(@due).getTime() - (new Date()).getTime()
        if msLeft < 0
            return "list-group-item-danger"
        if div(msLeft, 1000 * 60 * 60) < 24
            return "list-group-item-warning"
        if div(msLeft, 1000 * 60 * 60 * 24) < 2
            return "list-group-item-info"
        return ""

Template.assignments.helpers assignmentHelpers
Template.assignment_item.helpers assignmentHelpers

Template.assignment_item.events
    "click .check": ->
        Offline.smart.assignments().update this._id, {$set: done: !this.done}, ->
            Offline.save()

    "click .edit": (evt, tmpl) ->
        Session.set "editing_itemname", this._id

    "click .destroy": ->
        Offline.smart.assignments().remove this._id, ->
            Offline.save()

    "click .cancel": ->
        Session.set "editing_itemname", null

    "dblclick .assignment-text": (evt, tmpl) ->
        Session.set "editing_itemname", this._id
        Deps.flush() # update DOM before focus
        activateInput(tmpl.find("#assignment-input"))

    "dblclick abbr": (evt, tmpl) ->
        Session.set "editing_itemname", @_id
        Deps.flush()
        activateInput(tmpl.find("#due-date-input"))

$ ->
    if Math.max(document.documentElement.clientWidth, window.innerWidth || 0) < 768
        Template.assignment_item.events
            "change #due-date-input": ->
                Offline.smart.assignments().update this._id, {$set: text: $("#assignment-input").val(), due: DateOMatic.destringify($("#due-date-input").val())}, ->
                    Offline.save()
                Session.set "editing_itemname", null

Template.assignment_item.events okCancelEvents "#assignment-input",
    ok: (value) ->
        Offline.smart.assignments().update this._id, {$set: text: value, due: DateOMatic.destringify($("#due-date-input").val())}, ->
            Offline.save()
        Session.set "editing_itemname", null
    cancel: -> Session.set "editing_itemname", null

Template.assignment_item.events okCancelEvents "#due-date-input",
    ok: (value) ->
        Offline.smart.assignments().update this._id, {$set: text: $("#assignment-input").val(), due: DateOMatic.destringify($("#due-date-input").val())}, ->
            Offline.save()
        Session.set "editing_itemname", null
    cancel: -> Session.set "editing_itemname", null

# Tracking selected class in URL #

AssignmentsRouter = Backbone.Router.extend
    routes:
        ":class_id": "main"
    main: (class_id) ->
        Session.set "class_id", class_id
    setList: (class_id) ->
        @navigate class_id, trigger: true
        Session.set "class_id", class_id

Router = new AssignmentsRouter

Meteor.startup ->
    Backbone.history.start pushState: true
