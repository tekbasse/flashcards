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
    set flip_p 0
    set skip_p 0
    set pop_p 0
    set out_p 0
    set mode index
    
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
	if { [info exists input_array(skip) ] && $input_array(pop) ne "" } {
	    set pop_p 1
	}
	if { [info exists input_array(skip) ] && $input_array(out) ne "" } {
	    set out_p 1
	}
	
	# Determine mode, set mode to: index, frontside, backside
	if { $skip_p || $pop_p || $out_p } {
	    set mode frontside
	} elseif { $flip } {
	    set mode backside
	}
    }

    # Determine if displaying front or back side of card.
    # and mode of display.
    
    # implement mode via switch, which sets  up page and parameters for form.
    switch -exact -- $mode {
	index {
	    set stats_lol [db_list_of_lists flc_user_stats_r {
		select stack_id,
		time_start,
		time_end,
		cards_completed_count,
		cards_remaining_count,
		repeats_count
		from flc_user_stats 
		where instance_id=:instance_id
		and user_id=:user_id
		order by time_start desc } ]

	    set stack_lol [db_list_of_lists flc_stack_r {
		select stack_id, name, description
		from flc_card_stack
		where instance_id=:instance_id
		order by stack_id asc } ]

	    # Make this a radio list:
	    set carddeck_lol [list ]
	    if { [llength $stack_lol] > 0 } {
		set attr_list [list ]
		foreach stack_list $stack_lol {
		    set id [lindex $stack_list 0]
		    set name_arr(${id}) [lindex $stack_list 1]
		    set descr_arr(${id}) [lindex $stack_list 2]
		    # Make a radio list item with a label
		    # if new: stack, description (make a new deck)
		    # if incomplete: stack, started x, continue
		    set row_list [list value ${id} label "$name_arr(${id}): $descr_arr(${id})" ]
		    append attr_list $row_list
		}
		### Need to add unfished cases to attr_list
		
		    set f_lol [list \
				   [list type radio name stack_id value $attr_list
				   ]

		}
	    } else {
		set form_html "\#flashcards.None\#"
	    }
	    ##### instead of making a table, make a radio form. choose/start
	    # for new ones, and for user history cases that are not complete.
	    set avail_decks_html [qss_list_of_lists_to_html_table $carddeck_lol $carddeck_attrs_list]
	    append content_html <br> <br> "<h3>Available decks</h3>" \n $avail_decks_html \n
	    
	    # Make a table of user history for complete cases.
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

	}
	frontside {
	    # display first frontside of card this session,
	    #    requries:
	    #        stack_id, card_id(optional,but default)
	    #    user options: skip/pass 
	    #                  flip (to see backside) via form
	    
	    # display additonal frontside of cards
	    # after recording answer from last "backside" form post.
	    #    requires
	    #        stack_id, card_id (last)
	    #    system obtains next card_id
	    #    user options: skip/pass 
	    #                  flip (to see backside) via form

	}
	backside {
	    # display back card,
	    #    requires:
	    #         stack_id, card_id
	    #    user options:
	    #                 Put/Push back in stack
	    #                 Pop from stack
	}
    }

}


# build form
#  append form_html if it already exists.
# if f_lol, is empty, skip building a form.
