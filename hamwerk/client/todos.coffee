# Client-side JavaScript, bundled and sent to client.

# Define Minimongo collections to match server/publish.js.
@Classes = new Meteor.Collection "classes"
@Assignments = new Meteor.Collection "assignments"

# ID of currently selected class
Session.setDefault "class_id", null

# When editing a class name, ID of the class
Session.setDefault "editing_classname", null

# When editing assignment text, ID of the assignment
Session.setDefault "editing_itemname", null

# Subscribe to "classes" collection on startup.
# Select a class once data has arrived.
classesHandle = Meteor.subscribe "classes", -> Router?.setList ""

assignmentsHandle = null
# Always be subscribed to the assignments for the selected class.
Deps.autorun ->
    class_id = Session.get "class_id"
    console.log Meteor.userId()
    if class_id?
        assignmentsHandle = Meteor.subscribe("assignments", class_id)
    else if class_id is ""
        assignmentsHandle = Meteor.subscribe("assignments", "")
    else
        assignmentsHandle = null

Deps.autorun ->
    if !Meteor.userId()?
        Router?.setList("")

# Helpers for in-place editing #

# Returns an event map that handles the "escape" and "return" keys and
# "blur" events on a text input (given by selector) and interprets them
# as "ok" or "cancel".
okCancelEvents = (selector, callbacks) ->
    ok = callbacks.ok || ->
    cancel = callbacks.cancel || ->

    events = {}
    events["keyup #{selector}, keydown #{selector}, focusout #{selector}"] =
        (evt) ->
            if evt.type is "keydown" && evt.which is 27
                # escape = cancel
                cancel.call(this, evt)
            else if evt.type is "keyup" && evt.which is 13 || evt.type is "focusout"
                # blur/return/enter = ok/submit if non-empty
                value = String(evt.target.value || "")
                ok.call(this, value, evt)
    return events

activateInput = (input) ->
    input.focus()
    input.select()

# Classes #

Template.classes.loading = -> !classesHandle.ready()

Template.classes.classes = -> return Classes.find {}, sort: name: 1

Template.classes.fake_all_class_list = -> [_id: ""]

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
        id = Classes.insert name: text, user: Meteor.userId()
        Router.setList(id)
        evt.target.value = ""

Template.classes.events okCancelEvents "#class-name-input",
    ok: (value) ->
        if value isnt ""
            Classes.update this._id, $set: name: value
        else
            Meteor.call "nukeClass", this._id, -> Session.set "class_id", ""
        Session.set "editing_classname", null
    cancel: ->
        Session.set "editing_classname", null

Template.classes.active = ->
    if Session.equals("class_id", this._id) then "active" else ""

Template.classes.editing = -> Session.equals("editing_classname", this._id)

# Assignments #

Template.assignments.loading = -> assignmentsHandle && !assignmentsHandle.ready()

Template.assignments.any_class_selected = -> !Session.equals("class_id", null)

Template.assignments.events okCancelEvents "#new-assignment",
    ok: (text, evt) ->
        return unless text
        class_id = Session.get("class_id")
        if !class_id
            lowercaseText = text.toLowerCase()
            classes = Classes.find({}, fields: name: 1).fetch()
            guessedClass = _.find classes, (thisClass) -> lowercaseText.indexOf(thisClass.name.toLowerCase()) is 0
            if guessedClass?
                text = text.slice(guessedClass.name.length + 1)
                class_id = guessedClass._id
            else
                alert "No class specified"
                evt.target.value = ""
                return
        newAssignment =
            class_id: class_id
            done: false
            timestamp: (new Date()).getTime()
        text = text.slice(0, 1).toUpperCase() + text.slice(1).toLowerCase()
        dueDateMatch = /(.+) due (.+)/.exec text
        if dueDateMatch?
            newAssignment.text = dueDateMatch[1]
            newAssignment.due = DateOMatic.parseFuzzyFutureDate(dueDateMatch[2])
        else
            newAssignment.text = text
            newAssignment.due = DateOMatic.parseFuzzyFutureDate("tomorrow")
        Assignments.insert newAssignment
        evt.target.value = ""

logify = _.bind(console.log, console)

Template.assignments.assignments = ->
    # Determine which assignments to display in main pane,
    # selected based on class_id and tag_filter.

    class_id = Session.get "class_id"
    return {} unless class_id?

    sel = class_id: class_id
    if class_id is ""
        sel = {}
    
    return _(Assignments.find(sel).fetch()).chain()
           .sortBy((obj) -> obj.due.getTime())
           .sortBy("done")
           .groupBy("done")
           .pairs()
           .map(([truthiness, list]) -> _.sortBy(list, (obj) -> 
                if truthiness is "true"
                    Math.abs(DateOMatic.msDifferential(obj.due))
                else
                    obj.due.getTime()
            ))
           .reduce(((memo, list) -> memo.concat(list)), [])
           .value()

Template.assignment_item.precise_due_date = -> DateOMatic.stringify(@due)

Template.assignment_item.editable_due_date = -> DateOMatic.stringify(@due, no)

div = (a, b) -> (a - a % b) / b

Template.assignment_item.fuzzy_due_date = -> if DateOMatic.isFuture(@due) then "in #{DateOMatic.fuzzyDifferential(@due)}" else "#{DateOMatic.fuzzyDifferential(@due)} ago"

Template.assignment_item.done_class = -> if this.done then "muted" else ""

Template.assignment_item.done_checkbox = -> if this.done then "" else "-empty"

Template.assignment_item.editing = -> Session.equals("editing_itemname", this._id)

Template.assignment_item.editing_due_date = -> Session.equals("editing_due_date", @_id)

Template.assignment_item.text_class = ->
    if @done
        return "text-muted"
    msLeft = @due.getTime() - (new Date()).getTime()
    if msLeft < 0
        return "text-error"
    if div(msLeft, 1000 * 60 * 60) < 24
        return "text-warning"
    if div(msLeft, 1000 * 60 * 60 * 24) < 3
        return "text-info"
    return "text-success"

Template.assignment_item.events
    "click .check": ->
        Assignments.update this._id, $set: done: !this.done

    "click .destroy": -> Assignments.remove(this._id)

    "dblclick .assignment-text": (evt, tmpl) ->
        Session.set "editing_itemname", this._id
        Deps.flush() # update DOM before focus
        activateInput(tmpl.find("#assignment-input"))
    
    "dblclick abbr": (evt, tmpl) ->
        Session.set "editing_due_date", @_id
        Deps.flush()
        activateInput(tmpl.find("#due-date-input"))

Template.assignment_item.events okCancelEvents "#assignment-input",
    ok: (value) ->
        Assignments.update this._id, $set: text: value
        Session.set "editing_itemname", null
    cancel: -> Session.set "editing_itemname", null

Template.assignment_item.events okCancelEvents "#due-date-input",
    ok: (value) ->
        Assignments.update this._id, $set: due: DateOMatic.destringify(value)
        Session.set "editing_due_date", null
    cancel: -> Session.set "editing_due_date", null

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

loadIntercomActual = (force) ->
    if _.isFunction(window.Intercom)
        window.Intercom('reattach_activator')
        window.Intercom('update', intercomSettings)
    else
        i = (stuff...) -> i.c(stuff)
        i.q = []
        i.c = (args) -> i.q.push(args)
        window.Intercom = i
        l = ->
            s = document.createElement('script')
            s.type = 'text/javascript'
            s.async = true
            s.src = 'https://static.intercomcdn.com/intercom.v1.js'
            x = document.getElementsByTagName('script')[0]
            x.parentNode.insertBefore(s, x)
        if force
            l()
        else if w.attachEvent?
            w.attachEvent('onload', l)
        else
            w.addEventListener('load', l, false)

loadIntercom = (force = no) ->
    return Meteor.setTimeout((-> loadIntercomActual(force)), 250)

Meteor.startup ->
    Backbone.history.start pushState: true
    Meteor.call "hash", (error, user_hash) ->
        window.intercomSettings =
            # TODO: The current logged in user's email address.
            email: Meteor.user()?.emails[0].address
            swag_level: 100
            # TODO: The current logged in user's sign-up date as a Unix timestamp.
            created_at: Meteor.user()?.createdAt
            "widget": "activator": "#IntercomDefaultWidget"
            app_id: "2bb6ee6dc80fe8088dd8b40d21fa64fd5ab4db8a"
            user_hash: user_hash
        loadIntercom yes
