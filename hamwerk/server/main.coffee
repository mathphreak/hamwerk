# Classes -- name: String
#            user: String
#            color: String
#            schedule: Array
#                enabled: Boolean
#                time: String "hh:mm" (24-hour time)
@Classes = new Meteor.Collection "classes"

Classes.allow
    insert: (userId, doc) -> userId? and doc.user is userId
    update: (userId, doc) -> doc.user is userId
    remove: (userId, doc) -> doc.user is userId
    fetch: ["user"]

Classes.deny
    insert: (userId, doc) -> doc.name is ""
    update: (userId, doc, fieldNames) -> fieldNames.indexOf("user") isnt -1

# Publish complete set of classes to all clients.
Meteor.publish 'classes', -> Classes.find({user: @userId})


# Assignments -- text: String
#                done: Boolean
#                due: Date
#                class_id: String
#                timestamp: Number
@Assignments = new Meteor.Collection "assignments"

classMatches = (class_id, userId) -> Classes.findOne(class_id)?.user is userId

Assignments.allow
    insert: (userId, doc) -> userId? and classMatches(doc.class_id, userId)
    update: (userId, doc) -> classMatches(doc.class_id, userId)
    remove: (userId, doc) -> classMatches(doc.class_id, userId)
    fetch: ["class_id"]

Assignments.deny
    update: (userId, doc, fieldNames) -> fieldNames.indexOf("class_id") isnt -1

# Publish all items for that user
Meteor.publish 'assignments', ->
    throw new Meteor.Error(401, "Not logged in") unless @userId?
    userClasses = Classes.find({user: @userId}, {fields: {_id: 1}}).fetch()
    return Assignments.find({class_id: $in: _.pluck(userClasses, "_id")})

parseFuzzyDate = @DateOMatic.parseFuzzyFutureDate

Meteor.methods
    nukeClass: (class_id) ->
        if Classes.findOne(class_id).user is @userId
            Classes.remove class_id
            Assignments.remove {class_id: class_id}
        else
            throw new Meteor.Error(403, "This class doesn't belong to you")
    onboardMe: (clientOffset) ->
        serverOffset = new Date().getTimezoneOffset()
        minutesToAdd = clientOffset - serverOffset
        assignments = [
            ["Check off this assignment as complete by pressing the white box to its left", "today"]
            ["Edit this assignment by pressing the pencil, changing the text and/or due date, and pressing Enter", "tomorrow"]
            ["Remember that double-clicking also edits assignments, and if you can, try it", "tomorrow"]
            ["Delete the next assignment by editing it and pressing the red trash button on the right", "2 days from now"]
            ["THIS ASSIGNMENT NEEDS TO BE DELETED", "2 days from now"]
            ["Start editing this assignment, but then cancel by pressing the cancel button on the left", "3 days from now"]
            ["Remember that the Esc button also cancels when typing in either text box", "3 days from now"]
            ["Create a new assignment by following the placeholder at the top of this list", "4 days from now"]
            ["Create an assignment without a due date and see that it is due tomorrow", "5 days from now"]
            ["See all the ways to specify due dates by clicking the ? next to the assignment box", "6 days from now"]
            ["Create a new class by typing in the box below \"Hamwerk 101\" in the sidebar and pressing Enter", "7 days from now"]
            ["Create an assignment for that new class by typing its name before the assignment text", "8 days from now"]
            ["Select \"Hamwerk 101\" in the sidebar and see all these assignments", "9 days from now"]
            ["Create an assignment without typing \"Hamwerk 101\" first", "9 days from now"]
            ["Select your other class in the sidebar and make a new assignment without typing the class name, then go back to \"All Classes\"", "10 days from now"]
            ["See how the other class's assignment has a different color on the left", "10 days from now"]
            ["Edit \"Hamwerk 101\" by pressing the pencil in the sidebar, changing the name and color, and pressing \"Save\"", "11 days from now"]
            ["Remember that you can create a new class called \"Hamwerk 101\" to see this all again", "12 days from now"]
            ["Edit your new name for \"Hamwerk 101\" and press \"Delete\" to remove this class", "12 days from now"]
        ]

        oldOnboardingClassIDs = Classes.find({user: @userId, name: "Hamwerk 101"}).map((theClass) -> theClass._id)
        for oldClass in oldOnboardingClassIDs
            Assignments.remove({class_id: oldClass})
            Classes.remove(oldClass)
        class_id = Classes.insert(name: "Hamwerk 101", user: @userId, color: Please.make_color())
        timestamp = (new Date()).getTime()
        for [assignment, fuzzyDueDate] in assignments
            dueDate = parseFuzzyDate(fuzzyDueDate)
            dueDate.setMinutes(dueDate.getMinutes() + minutesToAdd)
            Assignments.insert(class_id: class_id, text: assignment, timestamp: timestamp, due: dueDate, done: no)
            timestamp += 1
        Meteor.users.update(@userId, $set: profile: onboarded: yes)

# if a user is created, create some sample data.
Accounts.onCreateUser (options, user) ->
    if options.profile?
        user.profile = options.profile
    else
        user.profile = {}
    user.profile.onboarded = no
    return user
