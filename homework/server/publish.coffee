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
    check(class_id, String)
    if class_id is ""
        return Assignments.find()
    return Assignments.find(class_id: class_id)

