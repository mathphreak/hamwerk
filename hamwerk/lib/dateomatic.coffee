monthNames = [
    "January"
    "February"
    "March"
    "April"
    "May"
    "June"
    "July"
    "August"
    "September"
    "October"
    "November"
    "December"
]

dowNames = [
    "Sunday"
    "Monday"
    "Tuesday"
    "Wednesday"
    "Thursday"
    "Friday"
    "Saturday"
]

pluralify = (rawAmount, singular) ->
    amount = Math.floor(rawAmount, 0)
    if amount is 1
        "#{amount} #{singular}"
    else
        "#{amount} #{singular}s"

pad = (number, digits) ->
    result = "#{number}"
    while result.length < digits
        result = "0#{result}"
    return result

@DateOMatic =
    stringify: (fakeDate, dow = yes, iso8601 = no, time = no) ->
        date = new Date(fakeDate)
        dowFragment = if dow then "#{dowNames[date.getDay()]}, " else ""
        timeFragment = if time
            if iso8601
                "T#{pad date.getHours(), 2}:#{pad date.getMinutes(), 2}"
            else
                " at #{pad date.getHours(), 2}:#{pad date.getMinutes(), 2}"
        else ""
        if iso8601
            "#{pad date.getFullYear(), 4}-#{pad date.getMonth()+1, 2}-#{pad date.getDate(), 2}#{timeFragment}"
        else
            "#{dowFragment}#{monthNames[date.getMonth()]} #{date.getDate()}, #{date.getFullYear()}#{timeFragment}"

    getDowName: (dow) -> dowNames[dow]

    getMonthName: (month) -> monthNames[month]

    msDifferential: (later) -> new Date(later).getTime() - (new Date()).getTime()

    isFuture: (later) -> @msDifferential(later) > 0

    fuzzyDifferential: (later) ->
        diff = @msDifferential(later)
        diff = -diff unless @isFuture(later)
        secondsDiff = diff / 1000
        if secondsDiff <= 60
            return pluralify(secondsDiff, 'second')
        minutesDiff = secondsDiff / 60
        if minutesDiff <= 60
            return pluralify(minutesDiff, 'minute')
        hoursDiff = minutesDiff / 60
        if hoursDiff <= 24
            return pluralify(hoursDiff, 'hour')
        daysDiff = hoursDiff / 24
        if daysDiff <= 7
            return pluralify(daysDiff, 'day')
        weeksDiff = daysDiff / 7
        if weeksDiff <= 4
            return pluralify(weeksDiff, 'week')
        monthsDiff = daysDiff / 30
        if daysDiff <= 365
            return pluralify(monthsDiff, 'month')
        yearsDiff = daysDiff / 365
        return pluralify(yearsDiff, 'year')

    destringify: (dateString) ->
        result = null
        iso8601Match = /(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d)/.exec(dateString)
        if iso8601Match?
            [..., y, m, d, hh, mm] = iso8601Match
            result = new Date(parseInt(y), parseInt(m) - 1, parseInt(d), parseInt(hh), parseInt(mm))
        else
            chunks = dateString.split(" ").map((x) -> if /,$/.test(x) then x.slice(0, -1) else x)
            if chunks.length is 4
                [dow, month, day, year] = chunks
            else if chunks.length is 3
                [month, day, year] = chunks
            result = new Date(parseInt(year), monthNames.indexOf(month), parseInt(day))
            if dow? and dowNames[result.getDay()] isnt dow
                throw new Error("Wrong day of week")
        return result

    parseFuzzyFutureDate: (input) ->
        result = new Date
        dateString = input.slice(0, 1).toUpperCase() + input.slice(1).toLowerCase()
        tomorrow = -> result.setDate(result.getDate() + 1)
        monthDayMatch = /^([A-Z][a-z]+) (\d+)(?:st|nd|rd|th)?$/.exec(dateString)
        absoluteDateMatches = /^(\w+,?\s)?\w+ \d+,? \d+$/.test(dateString)
        inNDaysMatch = /^(\d+) days from now$/i.exec(dateString)
        trimmedDowNames = dowNames.map((name) -> name.slice(0, 3))
        trimmedMonthNames = monthNames.map((name) -> name.slice(0, 3))
        if dateString is "Today"
            # do nothing
        else if dateString is "Tomorrow"
            tomorrow()
        else if dowNames.indexOf(dateString) > -1
            tomorrow()
            while dowNames[result.getDay()] isnt dateString
                tomorrow()
        else if trimmedDowNames.indexOf(dateString) > -1
            tomorrow()
            while trimmedDowNames[result.getDay()] isnt dateString
                tomorrow()
        else if monthDayMatch?
            month = monthDayMatch[1]
            day = monthDayMatch[2]
            monthNum = monthNames.indexOf(month)
            if monthNum is -1
                monthNum = trimmedMonthNames.indexOf(month)
            result.setMonth(monthNum)
            result.setDate(parseInt(day))
            while !@isFuture(result)
                result.setFullYear(result.getFullYear() + 1)
        else if absoluteDateMatches
            return @destringify(dateString)
        else if inNDaysMatch
            n = parseInt(inNDaysMatch[1])
            while n > 0
                tomorrow()
                n--
        else
            return null
        result.setHours(0)
        result.setMinutes(0)
        result.setSeconds(0)
        result.setMilliseconds(0)
        return new Date(result)

    parseFuzzyFutureDateAndTime: (input) ->
        result = new Date
        splitDateTimeMatch = /^(.*?) at (.*?)$/i.exec input
        if not splitDateTimeMatch?
            return null
        [..., dateString, timeString] = splitDateTimeMatch
        result = @parseFuzzyFutureDate(dateString)
        if result is null
            return null
        twelveHourTimeMatch = /^(\d?\d):(\d\d) (p|a)\.?m\.?$/i.exec timeString
        twentyFourHourTimeMatch = /^(\d\d):?(\d\d)$/.exec timeString
        if twelveHourTimeMatch?
            [..., hh, mm, pa] = twelveHourTimeMatch
            result.setHours (if pa.toLowerCase() is "p" then 12 else 0) + parseInt(hh)
            result.setMinutes parseInt mm
        else if twentyFourHourTimeMatch?
            [..., hh, mm] = twentyFourHourTimeMatch
            result.setHours parseInt hh
            result.setMinutes parseInt mm
        else
            return null
        return result

_.bindAll(DateOMatic, _.functions(DateOMatic)...)
