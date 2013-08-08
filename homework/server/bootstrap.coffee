# if the database is empty on server start, create some sample data.
Meteor.startup ->
    if Classes.find().count() is 0
        data = [
            {
                name: "Meteor Principles",
                contents: [
                    ["Data on the Wire", "Simplicity", "Better UX", "Fun"],
                    ["One Language", "Simplicity", "Fun"],
                    ["Database Everywhere", "Simplicity"],
                    ["Latency Compensation", "Better UX"],
                    ["Full Stack Reactivity", "Better UX", "Fun"],
                    ["Embrace the Ecosystem", "Fun"],
                    ["Simplicity Equals Productivity", "Simplicity", "Fun"]
                ]
            },
            {
                name: "Languages",
                contents: [
                    ["Lisp", "GC"],
                    ["C", "Linked"],
                    ["C++", "Objects", "Linked"],
                    ["Python", "GC", "Objects"],
                    ["Ruby", "GC", "Objects"],
                    ["JavaScript", "GC", "Objects"],
                    ["Scala", "GC", "Objects"],
                    ["Erlang", "GC"],
                    ["6502 Assembly", "Linked"]
                ]
            },
            {
                name: "Favorite Scientists",
                contents: [
                    ["Ada Lovelace", "Computer Science"],
                    ["Grace Hopper", "Computer Science"],
                    ["Marie Curie", "Physics", "Chemistry"],
                    ["Carl Friedrich Gauss", "Math", "Physics"],
                    ["Nikola Tesla", "Physics"],
                    ["Claude Shannon", "Math", "Computer Science"]
                ]
            }
        ]

        timestamp = (new Date()).getTime()
        for value in data
            class_id = Classes.insert(name: value.name)
            for info in value.contents
                Assignments.insert(class_id: class_id, text: info[0], timestamp: timestamp, tags: info.slice(1))
                timestamp += 1
