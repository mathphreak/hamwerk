# Lists -- {name: String}
@Classes = new Meteor.Collection "classes"

# Publish complete set of classes to all clients.
Meteor.publish 'classes', -> Classes.find()


# Assignments -- {text: String,
#                 done: Boolean,
#                 due: Date,
#                 class_id: String,
#                 timestamp: Number}
@Assignments = new Meteor.Collection "assignments"

# Publish all items for requested class_id.
Meteor.publish 'assignments', (class_id) ->
    check(class_id, String, Boolean)
    if class_id is ""
        return Assignments.find()
    return Assignments.find(class_id: class_id)

Meteor.methods
    hash: ->
        email = "mathphreak@gmail.com"
        hash = CryptoJS.HmacSHA256(email, intercomSecrets.secret_key)
        return hash.toString()
    nukeClass: (classID) ->
        Classes.remove classID
        Assignments.remove {class_id: classID}
        
# if the database is empty on server start, create some sample data.
Meteor.startup ->
    if Classes.find().count() is 0
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
            class_id = Classes.insert(name: value.name)
            for info in value.contents
                Assignments.insert(class_id: class_id, text: info[0], timestamp: timestamp, due: new Date(info[1]))
                timestamp += 1
