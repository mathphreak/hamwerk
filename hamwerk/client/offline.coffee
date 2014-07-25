@Offline = do =>
    cachedClassList = new Meteor.Collection null
    cachedAssignmentsList = new Meteor.Collection null

    loadCache = ->
        do =>
            loadedClassList = amplify.store "classes"
            cachedClassList = new Meteor.Collection null
            for clasz in loadedClassList
                cachedClassList.insert clasz

        do =>
            loadedAssignmentsList = amplify.store "assignments"
            cachedAssignmentsList = new Meteor.Collection null
            for assignment in loadedAssignmentsList
                cachedAssignmentsList.insert assignment

    loadCache()

    sync = ->
        # TODO make it work

    save = ->
        amplify.store "classes", Classes.find({}).fetch()
        amplify.store "assignments", Assignments.find({}).fetch()
        loadCache()

    return {
        sync: sync
        save: save
        classes: cachedClassList
        assignments: cachedAssignmentsList
        smart:
            classes: -> if online() then Classes else cachedClassList
            assignments: -> if online() then Assignments else cachedAssignmentsList
    }
