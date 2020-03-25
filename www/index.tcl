set title "#flashcards.Flashcards#"
set context [list $title]
set user_id [ad_conn user_id]
set instance_id [ad_conn package_id]
set read_p [permission::permission_p \
		-party_id $user_id \
		-object_id $instance_id \
		-privilege read]

set error_p 0
set form_html ""
set content_html ""
set user_message_list [list ]
set user_message_html ""
set page_mode_list [list "front" "back"]


if { !$read_p } {
    append content_html "\#flashcards.permission_denied\#"
} else {
    
    # defaults
    set field_list [list stack_id card_id page flip skip pop out]
    foreach f field_list {
	set input_array(${f}) ""
	set ${f} ""
    }
    # flip: flip fronside card to backside
    set flip_p 0
    # skip: don't flip card, keep it in deck
    set skip_p 0
    # pop: pop card from deck, display next card
    set pop_p 0
    # keep: keep card in deck, display next card 
    set keep_p 0
    set mode index
    set table_attrs_list [list border 1]
    
    set form_submitted_p [qf_get_inputs_as_array input_array]
    
    if { $form_submitted_p } {
	# Get possible inputs
	if { [qf_is_natural_number $input_array(stack_id) ] } {
	    set stack_id $input_array(stack_id)
	}
	if { [qf_is_natural_number $input_array(card_id) ] } {
	    set card_id $input_array(card_id)
	}
	if { $input_array(page) in $page_mode_list } {
	    set page $input_array(page)
	}
	if { [info exists input_array(flip) ] && $input_array(flip) ne "" } {
	    set flip_p 1
	}
	if { [info exists input_array(skip) ] && $input_array(skip) ne "" } {
	    set skip_p 1
	}
	if { [info exists input_array(pop) ] && $input_array(pop) ne "" } {
	    set pop_p 1
	}
	if { [info exists input_array(keep) ] && $input_array(keep) ne "" } {
	    set keep_p 1
	}
	
	# Determine mode, set mode to: index, frontside, backside
	if { $skip_p || $pop_p || $keep_p } {
	    set mode frontside
	} elseif { $flip && $card_id ne "" && $stack_id ne "" } {
	    set mode backside
	}
    }

    # Common to more than one mode:
    set stacks_lol [db_list_of_lists flc_stack_r {
	select stack_id, content_id, name, description
	from flc_card_stack
	where instance_id=:instance_id
	order by stack_id asc } ]

    set card_title(a) "\#flashcards.Abbreviation\#"
    set card_title(t) "\#flashcards.Term\#"
    set card_title(d) "\#flashcards.Description\#"
    
    # Determine if displaying front or back side of card.
    # and mode of display.
    
    # implement mode via switch, which sets  up page and parameters for form.
    switch -exact -- $mode {
	index {

	    # make a radio form 
	    # for new ones, and for user history cases that are not complete.
	    # with a start button

	    set active_lol [db_list_of_lists flc_user_stats_r {
		select stack_id,
		time_start
		from flc_user_stats 
		where instance_id=:instance_id 
		and user_id=:user_id
		and time_end is null
		order by time_start desc } ]

	    # Make this a radio list:
	    set carddeck_lol [list ]
	    if { [llength $stacks_lol] > 0 } {
		set attr_list [list ]
		foreach stack_list $stacks_lol {
		    lassign $stack_list id c_id name_arr(${id}) descr_arr(${id})
		    # Make a radio list item with a label
		    # if new: stack, description (make a new deck)
		    # if incomplete: stack, started x, continue

		    # First, new stacks
		    set row_list [list \
				      value ${id} label \
				      "$name_arr(${id}): $descr_arr(${id})" ]
		    append attr_list $row_list
		}
	    }
	    if {  [llength $active_lol] > 0 } {
		#  add unfinished cases to attr_list
		foreach active_list $active_lol {
		    lassign $active_list id time_start
		    set row_list [list \
				      value ${id} label \
				      "$name_arr(${id}): Started ${time_start}" ]
		    append attr_list $row_list
		}
	    }
	    if { [llength $f_lol ] > 0 } {
		append f_lol [list type radio \
				  name stack_id \
				  value $attr_list ]
		append f_lol [list type submit name submit \
				  value "\#flashcards.Start\#" datatype text label ""]
	    } else {
		set form_html "\#flashcards.None\#"
	    }
	    
	}
	frontside {
	    # increase view_count
	    set view_count ""
	    db1row flc_user_stack_r4 { select view_count
		from flc_user_stack where
		instance_id=:instance_id and
		user_id=:user_id and
		stack_id=:stack_id and
		card_id=:card_id and
		done_p !='t' }
	    if { $view_count eq "" } {
		set view_count 0
	    }
	    incr view_count
	    db_dml flc_user_stack_u0 { update flc_user_stack
		set view_count=:view_count where
		instance_id=:instance_id and
		user_id=:user_id and
		stack_id=:stack_id and
		card_id=:card_id and
		done_p !='t' }
	    
	    # If there is a 'pop' or 'keep' answer from backside,
	    # record it before rendering next frontside page.
	    if { $pop_p } {
		# remove the card from the deck
		db_dml flc_user_stack_u1 { update flc_user_stack
		    set done_p = 't' where
		    instance_id=:instance_id and
		    stack_id=:stack_id and
		    card_id=:card_id and
		    user_id=:user_id }
	    }
	    if { $keep_p } {
		# Put the card back in the deck, in a random place.
		# Get current order_id 
		db1row { select order_id
		    from flc_user_stack
		    where instance_id=:instance_id and
		    stack_id=:stack_id and
		    card_id=:card_id and
		    user_id=:user_id and
		    done_p != 't' }
		# Get last order_id in deck.
		# It may be the same as the current one.
		db_1row flc_user_stack_r1b {
		    select max( order_id) as order_id_last
		    from flc_user_stack
		    where instance_id=:instance_id and
		    stack_id=:stack_id and
		    user_id=:user_id and
		    done_p !='t' }
		# choose a random number inbetween
		set order_diff [expr { $order_id_last - $order_id } ]
		set order_id_new [randomRange $order_diff]
		incr order_id_new
		# assign current card to new number
		db_dml flc_user_stack_u2 { update flc_user_stack
		    set order_id=:order_id_new where
		    instance_id=:instance_id and
		    stack_id=:stack_id and
		    card_id=:card_id and
		    user_id=:user_id }
	    }

	    # display frontside of card 
	    #    requries:
	    #        stack_id, content_id, card_id (calculated)

	    # get next card_id
	    set card_id_exists_p [db_0or1row flc_user_stack_r3 {
		select card_id from flc_user_stack where
		instance_id=:instance_id and
		user_id=:user_id and
		stack_id=:stack_id and
		done_p!='t'
		order by order_id asc limit 1 } ]
	    if { !$card_id_exists_p } {
		append content_html {
		    <div style="align:center;"><p><strong>\#Done_Congratulations_\#</strong></p></div>}
	    } else {
		
		# Get card data
		set deck_list [lsearch -exact -integer -inline -index 0 $stacks_lol $stack_id]
		lassign $deck_list d_stack_id content_id deck_name deck_description
		    
		db_1row flc_card_stack_card_r1 {
		    select row_id,front_ref,back_ref
		    from flc_card_stack_card where
		    instance_id=:instance_id and
		    stack_id=:stack_id and
		    content_id=:content_id }
		# for front_ref,back_ref
		# a = abbreviation
		# t = term
		# d = description
		
		db_1row flc_content_r2 {
		    select abbreviation, term, description
		    from flc_content where
		    instance_id=:instance_id and
		    content_id=:content_id and
		    row_id=:row_id }
		set content_arr(a) $abbreviation
		set content_arr(t) $term
		set content_arr(d) $description

		# Build card view 
		#    user options: skip/pass 
		#                  flip (to see backside) via form
		append content_html "<h1>$card_title(${front_ref})</h1>\n"
		append content_html "<p><strong>$content_arr(${front_ref})</strong>"
		# Add the button choices as a form.
		######

	}
	backside {
	    # display back card,
	    #    requires:
	    #         stack_id, content_id, card_id
	    #    user options:
	    #                 Keep put/push back in stack
	    #                 Pop from stack
	}
    }

}


# build form
#  append form_html if it already exists.
# if f_lol, is empty, skip building a form.

    append content_html <br> <br> "<h3>History</h3>" \n $avail_decks_html \n
# At bottom of page,
    # make a table of user history for complete cases.
    set history_lol [db_list_of_lists flc_user_stats_r {
	select stack_id,
	time_start,
	time_end,
	cards_completed_count,
	cards_remaining_count,
	repeats_count
	from flc_user_stats 
	where instance_id=:instance_id 
	and user_id=:user_id
	and time_end is null
	order by time_start desc } ]
    

	set table_lol [list]
	    set titles_list [list "\#flashcards.Started\#" \
				 "\#flashcards.Stack\#" \
				 "\#flashcards.Finished\#" \
				 "\#flashcards.Completed\#" \
				 "\#flashcards.Remaining\#" \
				 "\#flashcards.Repeats\#" ]
	    set table_attrs_list [list border 1]
	    lappend table_lol $titles_list
	    if { [llength $stats_lol] < 1 } {
		set row_list [list "\#flashcards.None\#" "" "" "" "" "" ]
		lappend table_lol $row_list
	    } else {    
		foreach stat_list $stats_lol {
		    
		    set stack_id [lindex $stat_list 0]
		    set name $name_arr(${stack_id})

		    set row_list [lreplace $stat_list 0 0 $name]
		    append table_lol $row_list
		}
	    }

	    set table_html [qss_list_of_lists_to_html_table \
				$table_lol \
				$table_attrs_list]

	    set content_part2_html "<br><br><h3>Your history</h3>${table_html}"

