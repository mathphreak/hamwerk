@Offline = do =>
    cachedClassList = new Meteor.Collection null
    cachedAssignmentsList = new Meteor.Collection null

    do =>
        loadedClassList = amplify.store "classes"
        if loadedClassList?
            for clasz in loadedClassList
                cachedClassList.insert clasz

    do =>
        loadedAssignmentsList = amplify.store "assignments"
        if loadedAssignmentsList?
            for assignment in loadedAssignmentsList
                cachedAssignmentsList.insert assignment

    sync = ->
        # TODO make it work

    save = ->
        amplify.store "classes", Classes.find({}).fetch()
        amplify.store "assignments", Assignments.find({}).fetch()

    return {
        sync: sync
        save: save
        classes: cachedClassList
        assignments: cachedAssignmentsList
        smart:
            classes: -> if online() then Classes else cachedClassList
            assignments: -> if online() then Assignments else cachedAssignmentsList
    }
