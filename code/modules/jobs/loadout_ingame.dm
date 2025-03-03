//This file contains code for the ingame loadout selector, used by players AFTER they have already spawned into the round
//How to use? Simply add a /datum/outfit/loadout to the loadout_options list on each job, in the job_types folder

/mob/proc/select_loadout()
	set name = "Select Loadout"
	set category = "IC"


	//To select loadout, the mob must have a loadout selector component
	var/datum/component/loadout_selector/LS = GetComponent(/datum/component/loadout_selector)
	if (!istype(LS))
		//Error message, shouldn't be seen but just incase
		to_chat(src, ("You have either already selected a loadout, or have no options."))

		//If they don't have it, they shouldn't have this verb either
		disable_loadout_select(src)
		return

	LS.ui_interact(src)



//Called when someone spawns in, or maybe if an admin does a thing
/mob/proc/enable_loadout_select()
	//Delay the notification message for a few seconds so players are less likely to miss it
	spawn(5 SECONDS)
		to_chat(src, ("-------------------------------------------"))
		to_chat(src, ("Your job has additional loadout options you can choose from. Use the Loadout Selector in your hands, or the Select Loadout verb in the IC menu to choose your additional equipment."))
		to_chat(src, ("-------------------------------------------"))
	verbs += /mob/proc/select_loadout
	var/datum/component/loadout_selector/LS = AddComponent(/datum/component/loadout_selector) //Create the loadout selecting component
	var/token = new /obj/item/loadout_token
	LS.token = token
	put_in_hands(token)

//Cleans up the verbs, objects and components
//Called after a loadout is selected, or if the user tries to do some exploit to pick a second loadout
/mob/proc/disable_loadout_select()
	var/datum/component/loadout_selector/LS = GetComponent(/datum/component/loadout_selector)
	if (LS)
		//Lets close the open UI
		var/datum/tgui/ui = SStgui.try_update_ui(src, LS)
		if (ui)
			ui.close()

	verbs -= /mob/proc/select_loadout //Remove the verb
	RemoveComponentByType(/datum/component/loadout_selector) //Remove component

/****************
	Object
****************/
/obj/item/loadout_token
	name = "Select Loadout"
	desc = "Activate this item to select your additional loadout equipment. It will vanish once you're done."
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "random_loot"
	item_flags = DROPDEL

/obj/item/loadout_token/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, TRAIT_GENERIC)


/obj/item/loadout_token/attack_self(mob/user)
	user.select_loadout()

/****************
	Component
****************/
//A datum that handles the menu for loadout selecting, to save on adding variables to things
/datum/component/loadout_selector
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/list/loadout_options = list() //List of names and typepaths
	var/selected_name = "" //Name of the outfit currently selected
	var/datum/outfit/selected_datum = null //Reference to the datum of the outfit currently selected
	var/selected_items = list() //List of atoms in the selected outfit, this is a list of sublists in the format:
		//[{name: name, icon: icon, quantity: quantity}]

	//A list of names in a format that tgui likes, autogenerated
	var/list/data_names = list()

	var/obj/item/loadout_token/token = null

//Lets check that the assigned parent is a mob with a job
/datum/component/loadout_selector/Initialize()
	var/mob/living/L = parent
	if (istype(L))
		var/datum/job/J = L.GetJob()
		if (J && LAZYLEN(J.loadout_options))
			for (var/a in J.loadout_options) //Copy the options from the job
				var/datum/outfit/o = a
				loadout_options[initial(o.name)] = a
				data_names.Add(initial(o.name))
			return ..()

	//If they don't have a job they cant use this
	return COMPONENT_INCOMPATIBLE

//This completes loadout selection, spawns the selected outfit and cleans things up
/datum/component/loadout_selector/proc/finish()
	//First of all, safety checks
	if (!selected_datum || !parent || !token)
		return

	var/mob/M = parent
	var/obj/item/storage/backpack/duffelbag/equipment/duffelkit = new
	duffelkit.name = "equipment duffelbag"
	duffelkit.desc = "A duffelbag containing necessary equipment."
	duffelkit.w_class = WEIGHT_CLASS_BULKY
	selected_datum.spawn_at(duffelkit)
	M.dropItemToGround(token)
	QDEL_NULL(token)
	for (var/obj/item/book/granter/granter in duffelkit) //Auto consumes any books you spawn in with.
		granter.on_reading_finished(M)
	M.put_in_hands(duffelkit)
	M.disable_loadout_select()

/datum/component/loadout_selector/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "LoadoutSelect", "Loadout Select")
		ui.set_autoupdate(FALSE)
		ui.open()
		ui.send_asset(get_asset_datum(/datum/asset/spritesheet/loadout))

/datum/component/loadout_selector/ui_data(mob/user)
	var/list/data = list()
	data["outfits"] = data_names
	data["selected"] = selected_name
	if (selected_name)
		data["items"] = selected_items
	return data

/datum/component/loadout_selector/ui_act(action, params)
	if(..())
		return
	switch(action)
		if("loadout_select")
			select_outfit(params["name"])
		if("loadout_confirm")
			if (selected_datum)
				finish()
	return TRUE

//Selects an outfit and loads the preview of it
/datum/component/loadout_selector/proc/select_outfit(newname)
	//First of all, lets not do unnecessary work.
	//Don't reselect the one we already have selected
	if (newname == selected_name)
		return

	if (selected_datum)
		//Clean up old dummy/outfit
		QDEL_NULL(selected_datum)

	//Lets just make sure the desired outfit exists, too.
	//We do this after the cleanup so that we can pass null to deselect if desired
	if (!ispath(loadout_options[newname]))
		return

	//Ok we know we're selecting this, so
	selected_name = newname
	var/newtype = loadout_options[selected_name]
	selected_datum = new newtype
	selected_items = selected_datum.ui_data()
	SStgui.update_uis(src)
