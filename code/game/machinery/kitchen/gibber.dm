
/obj/machinery/gibber
	name = "Gibber"
	desc = "The name isn't descriptive enough?"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "grinder"
	density = 1
	anchored = 1
	var/operating = 0 //Is it on?
	var/dirty = 0 // Does it need cleaning?
	var/mob/living/occupant // Mob who has been put inside
	var/locked = 0 //Used to prevent mobs from breaking the feedin anim

	var/gib_throw_dir = WEST // Direction to spit meat and gibs in. Defaults to west.
	var/gibtime = 40 // Time from starting until meat appears

	use_power = 1
	idle_power_usage = 2
	active_power_usage = 500

//auto-gibs anything that bumps into it
/obj/machinery/gibber/autogibber
	var/turf/input_plate

/obj/machinery/gibber/autogibber/New()
	..()
	spawn(5)
		for(var/i in cardinal)
			var/obj/machinery/mineral/input/input_obj = locate( /obj/machinery/mineral/input, get_step(src.loc, i) )
			if(input_obj)
				if(isturf(input_obj.loc))
					input_plate = input_obj.loc
					del(input_obj)
					break

		if(!input_plate)
			log_misc("a [src] didn't find an input plate.")
			return

/obj/machinery/gibber/autogibber/Bumped(var/atom/A)
	if(!input_plate) return

	if(ismob(A))
		var/mob/M = A

		if(M.loc == input_plate)
			M.loc = src
			M.gib()


/obj/machinery/gibber/New()
	..()
	src.overlays += image('icons/obj/kitchen.dmi', "grjam")

/obj/machinery/gibber/update_icon()
	overlays.Cut()

	if (dirty)
		src.overlays += image('icons/obj/kitchen.dmi', "grbloody")

	if(stat & (NOPOWER|BROKEN))
		return

	if (!occupant)
		src.overlays += image('icons/obj/kitchen.dmi', "grjam")

	else if (operating)
		src.overlays += image('icons/obj/kitchen.dmi', "gruse")

	else
		src.overlays += image('icons/obj/kitchen.dmi', "gridle")

/obj/machinery/gibber/attack_paw(mob/user as mob)
	return src.attack_hand(user)

/obj/machinery/gibber/relaymove(mob/user as mob)
	if(locked)
		return

	src.go_out()

	return

/obj/machinery/gibber/attack_hand(mob/user as mob)
	if(stat & (NOPOWER|BROKEN))
		return

	if(operating)
		user << "<span class='danger'>The gibber is locked and running, wait for it to finish.</span>"
		return

	if(locked)
		user << "<span class='warning'>Wait for [occupant.name] to finish being loaded!</span>"
		return

	else
		src.startgibbing(user)

/obj/machinery/gibber/attackby(obj/item/weapon/grab/G as obj, mob/user as mob, params)
	if(!istype(G))
		return ..()

	if(G.state < 2)
		user << "<span class='danger'>You need a better grip to do that!</span>"
		return

	move_into_gibber(user,G.affecting)

	del(G)

/obj/machinery/gibber/MouseDrop_T(mob/target, mob/user)
	if(usr.stat || (!ishuman(user)) || user.restrained() || user.weakened || user.stunned || user.paralysis || user.resting)
		return

	if(!istype(target,/mob/living))
		return

	var/mob/living/targetl = target

	if(targetl.buckled)
		return

	move_into_gibber(user,target)

/obj/machinery/gibber/proc/move_into_gibber(var/mob/user,var/mob/living/victim)
	if(src.occupant)
		user << "<span class='danger'>The gibber is full, empty it first!</span>"
		return

	if(operating)
		user << "<span class='danger'>The gibber is locked and running, wait for it to finish.</span>"
		return

	if(!(istype(victim, /mob/living/carbon/human)))
		user << "<span class='danger'>This is not suitable for the gibber!</span>"
		return

	if(victim.abiotic(1))
		user << "<span class='danger'>Subject may not have abiotic items on.</span>"
		return

	user.visible_message("\red [user] starts to put [victim] into the gibber!")
	src.add_fingerprint(user)
	if(do_after(user, 30) && user.Adjacent(src) && victim.Adjacent(user) && !occupant)

		user.visible_message("\red [user] stuffs [victim] into the gibber!")

		if(victim.client)
			victim.client.perspective = EYE_PERSPECTIVE
			victim.client.eye = src

		victim.loc = src
		src.occupant = victim

		update_icon()
		feedinTopanim()

/obj/machinery/gibber/verb/eject()
	set category = "Object"
	set name = "Empty Gibber"
	set src in oview(1)

	if (usr.stat != 0)
		return

	src.go_out()
	add_fingerprint(usr)

	return

/obj/machinery/gibber/proc/go_out()
	if (operating || !src.occupant) //no going out if operating, just in case they manage to trigger go_out before being dead
		return

	if (locked)
		return

	for(var/obj/O in src)
		O.loc = src.loc

	if (src.occupant.client)
		src.occupant.client.eye = src.occupant.client.mob
		src.occupant.client.perspective = MOB_PERSPECTIVE

	src.occupant.loc = src.loc
	src.occupant = null

	update_icon()

	return

/obj/machinery/gibber/proc/feedinTopanim()
	if(!src.occupant)
		return

	src.layer = MOB_LAYER + 0.1

	src.locked = 1

	var/image/gibberoverlay = new
	gibberoverlay.icon = src.icon
	gibberoverlay.icon_state = "grinderoverlay"
	gibberoverlay.overlays += image('icons/obj/kitchen.dmi', "gridle")

	var/image/feedee = new
	occupant.dir = 2
	feedee.icon = getFlatIcon(occupant, 2)
	feedee.pixel_y = 25
	feedee.pixel_x = 2

	overlays += feedee
	overlays += gibberoverlay

	var/i //our counter
	for(i=0,i<30,i++) //32 tenths of a second (3.2seconds), counting from 0 to 31
		overlays -= gibberoverlay
		overlays -= feedee

		feedee.pixel_y--

		if(feedee.pixel_y == 16)
			feedee.icon += icon('icons/obj/kitchen.dmi', "footicon")
			continue

		if(feedee.pixel_y == -5)
			overlays -= feedee
			overlays -= gibberoverlay
			src.locked = 0
			break

		overlays += feedee
		overlays += gibberoverlay

		sleep(1)

	src.layer = 3

/obj/machinery/gibber/proc/startgibbing(mob/user as mob)
	if(src.operating)
		return

	if(!src.occupant)
		visible_message("<span class='danger'>You hear a loud metallic grinding sound.</span>")
		return

	use_power(1000)
	visible_message("<span class='danger'>You hear a loud squelchy grinding sound.</span>")

	src.operating = 1
	update_icon()

	var/slab_name = occupant.name
	var/slab_count = 3
	var/slab_type = /obj/item/weapon/reagent_containers/food/snacks/meat/human //gibber can only gib humans on paracode, no need to check meat type
	var/slab_nutrition = src.occupant.nutrition / 15

	slab_nutrition /= slab_count

	for(var/i=1 to slab_count)
		var/obj/item/weapon/reagent_containers/food/snacks/meat/new_meat = new slab_type(src)
		new_meat.name = "[slab_name] [new_meat.name]"
		new_meat.reagents.add_reagent("nutriment",slab_nutrition)

		if(src.occupant.reagents)
			src.occupant.reagents.trans_to(new_meat, round(occupant.reagents.total_volume/slab_count,1))

	new /obj/effect/decal/cleanable/blood/gibs(src)

	src.occupant.attack_log += "\[[time_stamp()]\] Was gibbed by <b>[user]/[user.ckey]</b>" //One shall not simply gib a mob unnoticed!
	user.attack_log += "\[[time_stamp()]\] Gibbed <b>[src.occupant]/[src.occupant.ckey]</b>"

	if(src.occupant.ckey)
		msg_admin_attack("[user.name] ([user.ckey])[isAntag(user) ? "(ANTAG)" : ""] gibbed [src.occupant] ([src.occupant.ckey]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

	if(!iscarbon(user))
		src.occupant.LAssailant = null
	else
		src.occupant.LAssailant = user

	src.occupant.emote("scream")
	playsound(src.loc, 'sound/effects/gib.ogg', 50, 1)

	src.occupant.death(1)
	src.occupant.ghostize()

	del(src.occupant)

	spawn(src.gibtime)

		playsound(src.loc, 'sound/effects/splat.ogg', 50, 1)
		operating = 0

		for (var/obj/item/thing in contents) //Meat is spawned inside the gibber and thrown out afterwards.
			thing.loc = get_turf(thing) // Drop it onto the turf for throwing.
			thing.throw_at(get_edge_target_turf(src,gib_throw_dir),rand(1,5),15) // Being pelted with bits of meat and bone would hurt.

		for (var/obj/effect/gibs in contents) //throw out the gibs too
			gibs.loc = get_turf(gibs) //drop onto turf for throwing
			gibs.throw_at(get_edge_target_turf(src,gib_throw_dir),rand(1,5),15)

		src.operating = 0
		update_icon()


