var/datum/subsystem/events/SSevent

/datum/subsystem/events
	name = "Events"
	priority = 6

	var/list/control = list()	//list of all datum/round_event_control. Used for selecting events based on weight and occurrences.
	var/list/running = list()	//list of all existing /datum/round_event

	var/scheduled = 0			//The next world.time that a naturally occuring random event can be selected.
	var/frequency_lower = 3000	//5 minutes lower bound.
	var/frequency_upper = 9000	//15 minutes upper bound. Basically an event will happen every 5 to 15 minutes.

	var/holiday					//This will be a string of the name of any realworld holiday which occurs today (GMT time)
	var/wizardmode = 0


/datum/subsystem/events/New()
	NEW_SS_GLOBAL(SSevent)


/datum/subsystem/events/Initialize()
	for(var/type in typesof(/datum/round_event_control))
		var/datum/round_event_control/E = new type()
		if(!E.typepath)
			continue				//don't want this one! leave it for the garbage collector
		if(E.wizardevent && !wizardmode)
			E.weight = 0
		control += E				//add it to the list of all events (controls)
	reschedule()
	getHoliday()
	..()


/datum/subsystem/events/fire()
	checkEvent()
	var/i=1
	for(var/thing in running)
		if(thing)
			thing:process()
			++i
			continue
		running.Cut(i,i+1)


//checks if we should select a random event yet, and reschedules if necessary
/datum/subsystem/events/proc/checkEvent()
	if(scheduled <= world.time)
		spawnEvent()
		reschedule()

//decides which world.time we should select another random event at.
/datum/subsystem/events/proc/reschedule()
	scheduled = world.time + rand(frequency_lower, max(frequency_lower,frequency_upper))

//selects a random event based on whether it can occur and it's 'weight'(probability)
/datum/subsystem/events/proc/spawnEvent()
	if(!config.allow_random_events)
//		var/datum/round_event_control/E = locate(/datum/round_event_control/dust) in control
//		if(E)	E.runEvent()
		return

	var/sum_of_weights = 0
	for(var/datum/round_event_control/E in control)
		if(E.occurrences >= E.max_occurrences)	continue
		if(E.earliest_start >= world.time)		continue
		if(E.holidayID)
			if(E.holidayID != holiday)			continue
		if(E.weight < 0)						//for round-start events etc.
			if(E.runEvent() == PROCESS_KILL)
				E.max_occurrences = 0
				continue
			message_admins("Random Event triggering: [E.name] ([E.typepath])")
			log_game("Random Event triggering: [E.name] ([E.typepath])")
			return
		sum_of_weights += E.weight

	sum_of_weights = rand(0,sum_of_weights)	//reusing this variable. It now represents the 'weight' we want to select

	for(var/datum/round_event_control/E in control)
		if(E.occurrences >= E.max_occurrences)	continue
		if(E.earliest_start >= world.time)		continue
		if(E.holidayID)
			if(E.holidayID != holiday)			continue
		sum_of_weights -= E.weight

		if(sum_of_weights <= 0)				//we've hit our goal
			if(E.runEvent() == PROCESS_KILL)//we couldn't run this event for some reason, set its max_occurrences to 0
				E.max_occurrences = 0
				continue
			message_admins("Random Event triggering: [E.name] ([E.typepath])")
			log_game("Random Event triggering: [E.name] ([E.typepath])")
			return


/datum/round_event/proc/findEventArea() //Here's a nice proc to use to find an area for your event to land in!
	var/list/safe_areas = list(
	/area/turret_protected/ai,
	/area/turret_protected/ai_upload,
	/area/engine,
	/area/solar,
	/area/holodeck,
	/area/shuttle
	)

	//These are needed because /area/engine has to be removed from the list, but we still want these areas to get fucked up.
	var/list/danger_areas = list(
	/area/engine/break_room,
	/area/engine/chiefs_office)

	//Need to locate() as it's just a list of paths.
	return locate(pick((the_station_areas - safe_areas) + danger_areas))


//allows a client to trigger an event
//aka Badmin Central
/client/proc/forceEvent()
	set name = "Trigger Event"
	set category = "Fun"

	if(!holder ||!check_rights(R_FUN))
		return

	holder.forceEvent()

/datum/admins/proc/forceEvent()
	var/dat 	= ""
	var/normal 	= ""
	var/magic 	= ""
	var/holiday = ""
	for(var/datum/round_event_control/E in SSevent.control)
		dat = "<BR><A href='?src=\ref[src];forceevent=\ref[E]'>[E]</A>"
		if(E.holidayID)
			holiday	+= dat
		else if(E.wizardevent)
			magic 	+= dat
		else
			normal 	+= dat

	dat = normal + "<BR>" + magic + "<BR>" + holiday

	var/datum/browser/popup = new(usr, "forceevent", "Force Random Event", 300, 750)
	popup.set_content(dat)
	popup.open()


/*
//////////////
// HOLIDAYS //
//////////////
//Uncommenting ALLOW_HOLIDAYS in config.txt will enable holidays

//It's easy to add stuff. Just modify getHoliday to set holiday to something using the switch for DD(#day) MM(#month) YY(#year).
//You can then check if it's a special day in any code in the game by doing if(events.holiday == "MyHolidayID")

//You can also make holiday random events easily thanks to Pete/Gia's system.
//simply make a random event normally, then assign it a holidayID string which matches the one you gave it in getHolday.
//Anything with a holidayID, which does not match the holiday string, will never occur.

//Please, Don't spam stuff up with stupid stuff (key example being april-fools Pooh/ERP/etc),
//And don't forget: CHECK YOUR CODE!!!! We don't want any zero-day bugs which happen only on holidays and never get found/fixed!

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//ALSO, MOST IMPORTANTLY: Don't add stupid stuff! Discuss bonus content with Project-Heads first please!//
//////////////////////////////////////////////////////////////////////////////////////////////////////////
~Carn */

//sets up the holiday string in the events manager.
/datum/subsystem/events/proc/getHoliday()
	if(!config.allow_holidays)	return		// Holiday stuff was not enabled in the config!
	holiday = null

	var/YY	=	text2num(time2text(world.timeofday, "YY")) 	// get the current year
	var/MM	=	text2num(time2text(world.timeofday, "MM")) 	// get the current month
	var/DD	=	text2num(time2text(world.timeofday, "DD")) 	// get the current day

	//Main switch. If any of these are too dumb/inappropriate, or you have better ones, feel free to change whatever
	switch(MM)
		if(1)	//Jan
			switch(DD)
				if(1)							holiday = "New Year"

		if(2)	//Feb
			switch(DD)
				if(2)							holiday = "Groundhog Day"
				if(14)							holiday = "Valentine's Day"
				if(17)							holiday = "Random Acts of Kindness Day"

		if(3)	//Mar
			switch(DD)
				if(14)							holiday = "Pi Day"
				if(17)							holiday = "St. Patrick's Day"
				if(27)
					if(YY == 16)
						holiday = "Easter"
				if(31)
					if(YY == 13)
						holiday = "Easter"

		if(4)	//Apr
			switch(DD)
				if(1)
					holiday = "April Fool's Day"
					if(YY == 18 && prob(50)) 	holiday = "Easter"
				if(5)
					if(YY == 15)				holiday = "Easter"
				if(16)
					if(YY == 17)				holiday = "Easter"
				if(20)
					holiday = "Four-Twenty"
					if(YY == 14 && prob(50))	holiday = "Easter"
				if(22)							holiday = "Earth Day"

		if(5)	//May
			switch(DD)
				if(1)							holiday = "Labour Day"
				if(4)							holiday = "FireFighter's Day"
				if(12)							holiday = "Owl and Pussycat Day"	//what a dumb day of observence...but we -do- have costumes already :3

		if(6)	//Jun

		if(7)	//Jul
			switch(DD)
				if(1)							holiday = "Doctor's Day"
				if(2)							holiday = "UFO Day"
				if(8)							holiday = "Writer's Day"
				if(30)							holiday = "Friendship Day"

		if(8)	//Aug
			switch(DD)
				if(5)							holiday = "Beer Day"

		if(9)	//Sep
			switch(DD)
				if(19)							holiday = "Talk-Like-a-Pirate Day"
				if(28)							holiday = "Stupid-Questions Day"

		if(10)	//Oct
			switch(DD)
				if(4)							holiday = "Animal's Day"
				if(7)							holiday = "Smiling Day"
				if(16)							holiday = "Boss' Day"
				if(31)							holiday = "Halloween"

		if(11)	//Nov
			switch(DD)
				if(1)							holiday = "Vegan Day"
				if(13)							holiday = "Kindness Day"
				if(19)							holiday = "Flowers Day"
				if(21)							holiday = "Saying-'Hello' Day"

		if(12)	//Dec
			switch(DD)
				if(10)							holiday = "Human-Rights Day"
				if(14)							holiday = "Monkey Day"
				if(21)							holiday = "Mayan Doomsday Anniversary"
				if(22)							holiday = "Orgasming Day"		//lol. These all actually exist
				if(24)							holiday = "Xmas"
				if(25)							holiday = "Xmas"
				if(26)							holiday = "Boxing Day"
				if(31)							holiday = "New Year"

	if(!holiday)
		//Friday the 13th
		if(DD == 13)
			if(time2text(world.timeofday, "DDD") == "Fri")
				holiday = "Friday the 13th"

	world.update_status()


/datum/subsystem/events/proc/toggleWizardmode()
	wizardmode = !wizardmode
	for(var/datum/round_event_control/E in SSevent.control)
		E.weight = initial(E.weight)
		if((E.wizardevent && !wizardmode) || (!E.wizardevent && wizardmode))
			E.weight = 0
	message_admins("Summon Events has been [wizardmode ? "enabled, events will occur every [SSevent.frequency_lower / 600] to [SSevent.frequency_upper / 600] minutes" : "disabled"]!")
	log_game("Summon Events was [wizardmode ? "enabled" : "disabled"]!")


/datum/subsystem/events/proc/resetFrequency()
	frequency_lower = initial(frequency_lower)
	frequency_upper = initial(frequency_upper)
