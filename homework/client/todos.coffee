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
classesHandle = Meteor.subscribe "classes", -> Router.setList ""

assignmentsHandle = null
# Always be subscribed to the assignments for the selected class.
Deps.autorun ->
    class_id = Session.get "class_id"
    if class_id?
        assignmentsHandle = Meteor.subscribe("assignments", class_id)
    else if class_id is ""
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
                if value
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
        id = Classes.insert name: text
        Router.setList(id)
        evt.target.value = ""

Template.classes.events okCancelEvents "#class-name-input",
    ok: (value) ->
        Classes.update this._id, $set: name: value
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
    
    return Assignments.find sel, sort: ["done", "due"]

Template.assignment_item.precise_due_date = -> @due.toDateString()

div = (a, b) -> (a - a % b) / b

overdueness = (msPastDue) ->
    secondsPastDue = div(msPastDue, 1000)
    if secondsPastDue < 60
        return "#{secondsPastDue} seconds ago"
    minutesPastDue = div(secondsPastDue, 60)
    if minutesPastDue < 60
        return "#{minutesPastDue} minutes ago"
    hoursPastDue = div(minutesPastDue, 60)
    if hoursPastDue < 24
        return "#{hoursPastDue} hours ago"
    daysPastDue = div(hoursPastDue, 24)
    if daysPastDue < 7
        return "#{daysPastDue} days ago"
    weeksPastDue = div(daysPastDue, 7)
    if weeksPastDue < 4
        return "#{weeksPastDue} weeks ago"
    return "a while back; give up now"

Template.assignment_item.fuzzy_due_date = ->
    msLeft = @due.getTime() - (new Date()).getTime()
    if msLeft < 0
        return overdueness(-msLeft)
    secondsLeft = div(msLeft, 1000)
    if secondsLeft < 60
        return "in #{secondsLeft} seconds"
    minutesLeft = div(secondsLeft, 60)
    if minutesLeft < 60
        return "in #{minutesLeft} minutes"
    hoursLeft = div(minutesLeft, 60)
    if hoursLeft < 24
        return "in #{hoursLeft} hours"
    daysLeft = div(hoursLeft, 24)
    if daysLeft < 7
        return "in #{daysLeft} days"
    weeksLeft = div(daysLeft, 7)
    if weeksLeft < 4
        return "in #{weeksLeft} weeks"
    return "in a while; don't sweat it"

Template.assignment_item.done_class = -> if this.done then "muted" else ""

Template.assignment_item.done_checkbox = -> if this.done then "" else "-empty"

Template.assignment_item.editing = -> Session.equals("editing_itemname", this._id)

Template.assignment_item.text_class = ->
    msLeft = @due.getTime() - (new Date()).getTime()
    if msLeft < 0
        return "text-error"
    if div(msLeft, 1000 * 60 * 60) < 12
        return "text-warning"
    if div(msLeft, 1000 * 60 * 60 * 24) < 3
        return "text-info"
    return "text-success"

Template.assignment_item.events
    "click .check": -> Assignments.update this._id, $set: done: !this.done

    "click .destroy": -> Assignments.remove(this._id)

    "dblclick .assignment-text": (evt, tmpl) ->
        Session.set "editing_itemname", this._id
        Deps.flush() # update DOM before focus
        activateInput(tmpl.find("#assignment-input"))

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
        Session.set "class_id", class_id
    setList: (class_id) -> @navigate class_id, true

Router = new AssignmentsRouter

Meteor.startup ->
    Backbone.history.start pushState: true
    `(function(){var w=window;var ic=w.Intercom;if(typeof ic==="function"){ic('reattach_activator');ic('update',intercomSettings);}else{var d=document;var i=function(){i.c(arguments)};i.q=[];i.c=function(args){i.q.push(args)};w.Intercom=i;function l(){var s=d.createElement('script');s.type='text/javascript';s.async=true;s.src='https://static.intercomcdn.com/intercom.v1.js';var x=d.getElementsByTagName('script')[0];x.parentNode.insertBefore(s,x);}if(w.attachEvent){w.attachEvent('onload',l);}else{w.addEventListener('load',l,false);}};})()`

window.intercomSettings =
    # TODO: The current logged in user's email address.
    email: "mathphreak@gmail.com",
    # TODO: The current logged in user's sign-up date as a Unix timestamp.
    created_at: 0,
    "widget": "activator": "#IntercomDefaultWidget"
    app_id: "2bb6ee6dc80fe8088dd8b40d21fa64fd5ab4db8a"