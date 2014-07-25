# Client-side JavaScript, bundled and sent to client.

# Define Minimongo collections to match server/publish.js.
@Classes = new Meteor.Collection "classes"
@Assignments = new Meteor.Collection "assignments"

@online = -> Meteor.status().status is "connected"

# ID of currently selected class
Session.setDefault "class_id", ""

# When editing a class name, ID of the class
Session.setDefault "editing_classname", null

# When editing assignment text, ID of the assignment
Session.setDefault "editing_itemname", null

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

Template.contents.showEverything = ->
    return true if Meteor.userId()?
    return true if !online
    return false

# Classes #

Template.classes.classes = -> return Offline.smart.classes().find {}, sort: name: 1

Template.classes.fake_all_class_list = -> [_id: ""]

Template.classes.create_disabled = -> if online() then "" else "disabled"
Template.new_assignment_box.disabled = -> if online() then "" else "disabled"

Template.classes.events
    "mousedown .class": (evt) -> Router.setList(this._id) if @_id?
    "click .class": (evt) -> evt.preventDefault()
    "dblclick .class": (evt, tmpl) -> # start editing class name
        Session.set "editing_classname", this._id
        Deps.flush() # force DOM redraw, so we can focus the edit field
        activateInput(tmpl.find("#class-name-input"))

# Attach events to keydown, keyup, and blur on "New class" input box.
Template.classes.events okCancelEvents "#new-class",
    ok: (text, evt) ->
        if text is "Hamwerk 101"
            Meteor.users.update(Meteor.userId(), {$set: {profile: {onboarded: false}}})
        else
            id = Offline.smart.classes().insert {name: text, user: Meteor.userId()}, ->
                Meteor.subscribe("assignments")
                Offline.save()
        evt.target.value = ""

Template.classes.events okCancelEvents "#class-name-input",
    ok: (value) ->
        if value isnt ""
            Offline.smart.classes().update this._id, {$set: name: value}, ->
                Offline.save()
        else
            Meteor.call "nukeClass", this._id, ->
                Router?.setList ""
                Offline.save()
        Session.set "editing_classname", null
    cancel: ->
        Session.set "editing_classname", null

Template.classes.active = ->
    if Session.equals("class_id", this._id)
        "active"
    else
        ""

Template.classes.editing = -> Session.equals("editing_classname", this._id)

# New Assignment Box #

rand = (min, max) -> Math.floor(Math.random() * (max - min + 1) + min)

Template.new_assignment_box.sample = ->
    task = "read chapter #{rand(1, 15)} due #{DateOMatic.getDowName(rand(0, 6))}"
    if Session.equals("class_id", "")
        "#{_(Offline.smart.classes().find().fetch()).chain().pluck('name').shuffle().value()[0]} #{task}"
    else
        "#{task}"

# Assignments #

Template.assignments.events okCancelEvents "#new-assignment",
    ok: (text, evt) ->
        return unless text
        class_id = Session.get("class_id")
        if !class_id
            lowercaseText = text.toLowerCase()
            classes = Offline.smart.classes().find({}, fields: name: 1).fetch()
            guessedClass = _.find classes, (thisClass) -> lowercaseText.indexOf(thisClass.name.toLowerCase()) is 0
            if guessedClass?
                text = text.slice(guessedClass.name.length + 1)
                if text.trim() is ""
                    alert "No assignment specified"
                    $("#new-assignment").parent().addClass("has-error")
                    return
                class_id = guessedClass._id
            else
                alert "No class specified"
                $("#new-assignment").parent().addClass("has-error")
                return
        newAssignment =
            class_id: class_id
            done: false
            timestamp: (new Date()).getTime()
        text = text.slice(0, 1).toUpperCase() + text.slice(1).toLowerCase()
        dueDateMatch = /(.+) (?:due|do|for) (.+)/.exec text
        parsedDate = DateOMatic.parseFuzzyFutureDate("tomorrow")
        newAssignment.text = text
        newAssignment.due = parsedDate
        if dueDateMatch?
            parsedDate = DateOMatic.parseFuzzyFutureDate(dueDateMatch[2])
            if parsedDate isnt null
                newAssignment.text = dueDateMatch[1]
                newAssignment.due = parsedDate
        Offline.smart.assignments().insert newAssignment, ->
            Offline.save()
        evt.target.value = ""
    dirty: (text, evt) ->
        $("#new-assignment").parent().removeClass("has-error")
        return unless text
        class_id = Session.get("class_id")
        if !class_id
            lowercaseText = text.toLowerCase()
            classes = Offline.smart.classes().find({}, fields: name: 1).fetch()
            guessedClass = _.find classes, (thisClass) -> lowercaseText.indexOf(thisClass.name.toLowerCase()) is 0
            if guessedClass?
                text = text.slice(guessedClass.name.length + 1)
                if text.trim() is ""
                    $("#new-assignment").parent().addClass("has-error")
                    return
                class_id = guessedClass._id
            else
                $("#new-assignment").parent().addClass("has-error")
                return
        dueDateMatch = /(.+) (?:due|do|for) (.+)/.exec text
        if dueDateMatch?
            parsedDate = DateOMatic.parseFuzzyFutureDate(dueDateMatch[2])
            if parsedDate is null
                # tried and failed to specify a valid date
                $("#new-assignment").parent().addClass("has-error")
                return

Template.assignments.assignments = ->
    # Determine which assignments to display in main pane,
    # selected based on class_id and tag_filter.
    class_id = Session.get "class_id"

    sel = class_id: class_id
    if class_id is ""
        sel = {}

    return _(Offline.smart.assignments().find(sel).fetch()).chain()
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

Template.assignment_item.precise_due_date = -> DateOMatic.stringify(@due)

Template.assignment_item.editable_due_date = -> DateOMatic.stringify(@due, no)

div = (a, b) -> (a - a % b) / b

Template.assignment_item.fuzzy_due_date = -> if DateOMatic.isFuture(@due) then "in #{DateOMatic.fuzzyDifferential(@due)}" else "#{DateOMatic.fuzzyDifferential(@due)} ago"

Template.assignment_item.done_class = -> if this.done then "muted" else ""

Template.assignment_item.done_checkbox = -> if this.done then "check-" else ""

Template.assignment_item.editing = -> Session.equals("editing_itemname", this._id)

Template.assignment_item.color_class = ->
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

Template.assignment_item.events
    "click .check": ->
        Offline.smart.assignments().update this._id, {$set: done: !this.done}, ->
            Offline.save()

    "click .edit": (evt, tmpl) ->
        Session.set "editing_itemname", this._id
        Deps.flush() # update DOM before focus
        activateInput(tmpl.find("#assignment-input"))

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

Template.assignment_item.events okCancelEvents "#assignment-input",
    ok: (value) ->
        Offline.smart.assignments().update this._id, {$set: text: value}, ->
            Offline.save()
        Session.set "editing_itemname", null
    cancel: -> Session.set "editing_itemname", null

Template.assignment_item.events okCancelEvents "#due-date-input",
    ok: (value) ->
        Offline.smart.assignments().update this._id, {$set: due: DateOMatic.destringify(value)}, ->
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
