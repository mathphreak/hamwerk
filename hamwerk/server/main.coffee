# Classes -- {name: String, user: String}
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


# Assignments -- {text: String,
#                 done: Boolean,
#                 due: Date,
#                 class_id: String,
#                 timestamp: Number}
@Assignments = new Meteor.Collection "assignments"

classMatches = (class_id, userId) -> Classes.findOne(class_id)?.user is userId

Assignments.allow
    insert: (userId, doc) -> userId? and classMatches(doc.class_id, userId)
    update: (userId, doc) -> classMatches(doc.class_id, userId)
    remove: (userId, doc) -> classMatches(doc.class_id, userId)
    fetch: ["class_id"]

Assignments.deny
    update: (userId, doc, fieldNames) -> fieldNames.indexOf("class_id") isnt -1

# Publish all items for requested class_id.
Meteor.publish 'assignments', (class_id) ->
    check(class_id, String)
    throw new Meteor.Error(401, "Not logged in") unless @userId?
    if class_id is ""
        return Assignments.find({class_id: $in: _.pluck(Classes.find({user: @userId}, {fields: _id: 1}).fetch(), "_id")})
    if Classes.findOne(class_id)?.user isnt @userId
        throw new Meteor.Error(403, "This class doesn't belong to you")
    return Assignments.find(class_id: class_id)

Meteor.methods
    hash: ->
        email = Meteor.users.findOne(_id: @userId)?.emails[0].address
        hash = CryptoJS.HmacSHA256(email, intercomSecrets.secret_key)
        return hash.toString()
    nukeClass: (class_id) ->
        if Classes.findOne(class_id).user is @userId
            Classes.remove class_id
            Assignments.remove {class_id: class_id}
        else
            throw new Meteor.Error(403, "This class doesn't belong to you")

createOnboarding = (user) ->
    userId = user._id
    assignments = [
        ["Check off this assignment as complete by pressing the white box to its left", "today"]
        ["Delete the next assignment by pressing the trash icon on the right", "tomorrow"]
        ["THIS ASSIGNMENT NEEDS TO BE DELETED", "2 days from now"]
        ["Edit the text of this assignment by double-clicking it, changing it, and pressing Enter", "3 days from now"]
        ["Edit the due date of this assignment by double-clicking the due date, entering a new date, and pressing Enter", "3 days from now"]
        ["Create a new assignment by following the placeholder at the top of this list", "4 days from now"]
        ["Create an assignment without a due date and see that it is due tomorrow", "4 days from now"]
        ["Create an assignment \"due today\"", "5 days from now"]
        ["Create an assignment \"due tomorrow\"", "5 days from now"]
        ["Create an assignment \"due April 4th\" or some other day", "5 days from now"]
        ["Create an assignment \"due June 17, 2015\" or some other date", "5 days from now"]
        ["Create an assignment \"due Friday\" or some other day", "5 days from now"]
        ["Create an assignment \"due Wed\" or some other day", "5 days from now"]
        ["Create an assignment \"due 3 days from now\" or some other number", "5 days from now"]
        ["Create a new class by typing in the box below \"Hamwerk 101\" in the sidebar and pressing Enter", "6 days from now"]
        ["Create an assignment for that new class by typing its name before the assignment text", "7 days from now"]
        ["Select \"Hamwerk 101\" in the sidebar and see all these assignments", "8 days from now"]
        ["Create an assignment without typing \"Hamwerk 101\" first", "8 days from now"]
        ["Select your other class in the sidebar and make a new assignment without typing the class name, then go back to \"All Classes\"", "9 days from now"]
        ["Double-click the \"Hamwerk 101\" label in the sidebar and change this class's name to something else", "10 days from now"]
        ["Double-click your new name for \"Hamwerk 101,\" delete it, and hit Enter to remove this class", "11 days from now"]
    ]

    oldOnboardingClassIDs = Classes.find({name: "Hamwerk 101"}).map((theClass) -> theClass._id)
    for oldClass in oldOnboardingClassIDs
        Assignments.remove({class_id: oldClass})
        Classes.remove(oldClass)
    class_id = Classes.insert(name: "Hamwerk 101", user: userId)
    timestamp = (new Date()).getTime()
    for [assignment, dueDate] in assignments
        Assignments.insert(class_id: class_id, text: assignment, timestamp: timestamp, due: @DateOMatic.parseFuzzyFutureDate(dueDate), done: no)
        timestamp += 1
    user.onboarded = yes

# if a user is created, create some sample data.
Accounts.onCreateUser (options, user) ->
    createOnboarding user
    if options.profile?
        user.profile = options.profile
    return user

Meteor.startup ->
    onboardingUsers = Meteor.users.find({onboarded: {$nin: [yes]}}).fetch()
    onboardingUsers.forEach createOnboarding
    onboardingUsers.forEach (user) -> Meteor.users.update user._id, user
