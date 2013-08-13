# Classes -- {name: String, user: String}
@Classes = new Meteor.Collection "classes"

# Publish complete set of classes to all clients.
Meteor.publish 'classes', -> Classes.find({user: @userId})


# Assignments -- {text: String,
#                 done: Boolean,
#                 due: Date,
#                 class_id: String,
#                 timestamp: Number}
@Assignments = new Meteor.Collection "assignments"

# Publish all items for requested class_id.
Meteor.publish 'assignments', (class_id) ->
    check(class_id, String)
    throw new Meteor.Error(401, "Not logged in") unless @userId?
    if class_id is ""
        return Assignments.find({class_id: $in: _.pluck(Classes.find({user: @userId}, {fields: _id: 1}).fetch(), "_id")})
    if Classes.findOne(class_id).user isnt @userId
        throw new Meteor.Error(403, "This class doesn't belong to you")
    return Assignments.find(class_id: class_id)

Meteor.methods
    hash: ->
        email = Meteor.users.findOne(_id: @userId)?.emails[0].address
        hash = CryptoJS.HmacSHA256(email, intercomSecrets.secret_key)
        return hash.toString()
    nukeClass: (classID) ->
        Classes.remove classID
        Assignments.remove {class_id: classID}
        
# if a user is created, create some sample data.
Accounts.onCreateUser (options, user) ->
    userId = user._id
    if Classes.find({user: userId}).count() is 0
        data = [
            {
                name: "Physics",
                contents: [
                    ["Lab report", "Aug 5, 2013"],
                    ["Chapter 14-2, problems 15-26 odd", "Nov 19, 2013"]
                ]
            },
            {
                name: "Student Council",
                contents: [
                    ["Paper on leadership", "Aug 20, 2013"],
                    ["Presentation on leadership", "Aug 24, 2013"],
                    ["Draft amendment", "Sep 1, 2013"]
                ]
            },
            {
                name: "English",
                contents: [
                    ["Research paper outline", "Oct 12, 2013"],
                    ["1337 SWAG", "Oct 11, 2013"]
                ]
            }
        ]

        timestamp = (new Date()).getTime()
        for value in data
            class_id = Classes.insert(name: value.name, user: userId)
            for info in value.contents
                Assignments.insert(class_id: class_id, text: info[0], timestamp: timestamp, due: new Date(info[1]))
                timestamp += 1
    if options.profile?
        user.profile = options.profile
    return user
