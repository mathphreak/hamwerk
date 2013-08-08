# Client-side JavaScript, bundled and sent to client.

# Define Minimongo collections to match server/publish.js.
@Classes = new Meteor.Collection "classes"
@Assignments = new Meteor.Collection "assignments"

# ID of currently selected class
Session.setDefault "class_id", null

# Name of currently selected tag for filtering
Session.setDefault "tag_filter", null

# When adding tag to a assignment, ID of the assignment
Session.setDefault "editing_addtag", null

# When editing a class name, ID of the class
Session.setDefault "editing_classname", null

# When editing assignment text, ID of the assignment
Session.setDefault "editing_itemname", null

# Subscribe to "classes" collection on startup.
# Select a class once data has arrived.
classesHandle = Meteor.subscribe "classes", ->
    if !Session.get("class_id")?
        thisClass = Classes.findOne {}, sort: name: 1
        if thisClass?
            Router.setList thisClass._id

assignmentsHandle = null
# Always be subscribed to the assignments for the selected class.
Deps.autorun ->
    class_id = Session.get "class_id"
    if class_id?
        assignmentsHandle = Meteor.subscribe("assignments", class_id)
    else
        assignmentsHandle = null


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
                if value?
                    ok.call(this, value, evt)
                else
                    cancel.call(this, evt)
    return events

activateInput = (input) ->
    input.focus()
    input.select()

# Classes #

Template.classes.loading = -> !classesHandle.ready()

Template.classes.classes = -> return Classes.find {}, sort: name: 1

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
        id = Classes.insert name: text
        Router.setList(id)
        evt.target.value = ""

Template.classes.events okCancelEvents "#class-name-input",
    ok: (value) ->
        Classes.update this._id, $set: name: value
        Session.set "editing_classname", null
    cancel: ->
        Session.set "editing_classname", null

Template.classes.active = -> if Session.equals("class_id", this._id) then "active" else ""

Template.classes.name_class = -> if this.name then "" else "empty"

Template.classes.editing = -> Session.equals("editing_classname", this._id)

# Assignments #

Template.assignments.loading = -> assignmentsHandle && !assignmentsHandle.ready()

Template.assignments.any_class_selected = -> !Session.equals("class_id", null)

Template.assignments.events okCancelEvents "#new-assignment",
    ok: (text, evt) ->
        tag = Session.get "tag_filter"
        Assignments.insert
            text: text,
            class_id: Session.get("class_id"),
            done: false,
            timestamp: (new Date()).getTime(),
            tags: if tag then [tag] else []
        evt.target.value = ""

Template.assignments.assignments = ->
    # Determine which assignments to display in main pane,
    # selected based on class_id and tag_filter.

    class_id = Session.get "class_id"
    if !class_id
        return {}

    sel = class_id: class_id
    tag_filter = Session.get "tag_filter"
    sel.tags = tag_filter if tag_filter?
    
    return Assignments.find sel, sort: timestamp: 1

Template.assignment_item.tag_objs = ->
    assignment_id = this._id
    _.map this.tags || [], (tag) -> {assignment_id: assignment_id, tag: tag}

Template.assignment_item.done_class = -> if this.done then "muted" else ""

Template.assignment_item.done_checkbox = -> if this.done then "" else "-empty"

Template.assignment_item.editing = -> Session.equals("editing_itemname", this._id)

Template.assignment_item.adding_tag = -> Session.equals("editing_addtag", this._id)

Template.assignment_item.events
    "click .check": -> Assignments.update this._id, $set: done: !this.done

    "click .destroy": -> Assignments.remove(this._id)

    "click .addtag": (evt, tmpl) ->
        Session.set "editing_addtag", this._id
        Deps.flush() # update DOM before focus
        activateInput(tmpl.find("#edittag-input"))

    "dblclick .display .assignment-text": (evt, tmpl) ->
        Session.set "editing_itemname", this._id
        Deps.flush() # update DOM before focus
        activateInput(tmpl.find("#assignment-input"))

    "click .remove": (evt) ->
        tag = this.tag
        id = this.assignment_id

        evt.target.parentNode.style.opacity = 0
        # wait for CSS animation to finish
        Meteor.setTimeout(->
            Assignments.update({_id: id}, {$pull: {tags: tag}})
        , 300)

Template.assignment_item.events okCancelEvents "#assignment-input",
    ok: (value) ->
        Assignments.update this._id, $set: text: value
        Session.set "editing_itemname", null
    cancel: -> Session.set "editing_itemname", null

Template.assignment_item.events okCancelEvents "#edittag-input",
    ok: (value) ->
        Assignments.update this._id, $addToSet: tags: value
        Session.set "editing_addtag", null
    cancel: -> Session.set "editing_addtag", null

# Tracking selected class in URL #

AssignmentsRouter = Backbone.Router.extend
    routes:
        ":class_id": "main"
    main: (class_id) ->
        oldList = Session.get "class_id"
        if oldList isnt class_id
            Session.set "class_id", class_id
            Session.set "tag_filter", null
    setList: (class_id) -> @navigate class_id, true

Router = new AssignmentsRouter

Meteor.startup -> Backbone.history.start pushState: true
