

set title ""
set form_html ""
set content_html ""
set user_message_list [list ]
set user_message_html ""
set title "\#flashcards.Frontside\#"

set user_id [ad_conn user_id]
set instance_id [ad_conn package_id]
set read_p [permission::permission_p \
		-party_id $user_id \
		-object_id $instance_id \
		-privilege read]

if { $read_p } {
    
    # defaults
    set input_array(frontside_p) 1
    set input_array(stock_id) ""
    set input_array(card_id) ""
    
    set form_submitted_p [qf_get_inputs_as_array input_array]
    if { $form_submitted_p } {
	# Get possible inputs
	set frontside_p [qf_is_true $input_array(frontside_p) 1]
	if { [qf_is_natural_number $input_array(stock_id) ] } {
	    set stock_id $input_array(stock_id)
	}
	if { [qf_is_natural_number $input_array(card_id) ] } {
	    set card_id $input_array(card_id)
	}
	
    }

    if { $stack_id eq "" } {
	set card_id ""
	# Try to get one
	
	# No references provided. # Let's guess at what the stack is.
	# warn, this should't happen

	# Check if user has an incomplete stack or two
	# If so, choose the most recent incomplete one.

	set stack_id_found_p [db_0or1row flc_user_stats_rN1 {
	    select stack_id from flc_user_stats
	    where instance_id=:instance_id
	    and user_id=:user_id
	    and time_end is null
	    order by time_start desc limit 1} ]
	
	if { !$stack_id_found_p } {
	    
	    # Check if there's only one stack available to start
	    # If so, choose it.
	    set stack_id_list [db_0or1row flc_card_stack_rN1 {
		select stack_id from flc_card_stack
		where instance_id=:instance_id
	    } ]
	    if { [llength $stack_id_list ] == 1 } {
		set stack_id [lindex $stack_id_list 0]
	    }
	}
    }
    if { $stack_id eq "" } {
	lappend user_message_list "Missing card deck info. Browse <a href=\"index\">here</a> to try again."
    } else {

	if { $frontside_p } {
	    # Determine if displaying front or back side of card.
	    # and mode of display.
	    # modes:
	    # display first frontside of card this session,
	    #    requries:
	    #        stack_id, card_id(optional)
	    #    user options: skip/pass (link to same page)
	    #                  flip (to see backside) via form
	    
	    # display frontside of card
	    # after recording answer from last "backside" form post.
	    #    requires
	    #        stack_id, card_id optional
	    #    user options: skip/pass (link to same page)
	    #                  flip (to see backside) via form
	} else {
	    # display back card,
	    #    requires:
	    #         stack_id, card_id, frontside_p == 0
	    #    user options:
	    #                 Put back in stack
	    #                 Pop from stack
	    



	}

	
    if { !$frontside_p } {
	set title "\#flashcards.Backside\#"
    }
    set context [list [list index "\#flashcards.Flashcards\#"] $title]
    foreach user_message $user_message_list {
        append user_message_html "<li>${user_message}</li>"
    }
    # end of html page
	
    
    
    # following to be changed.. code from www/index.tcl
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

    set carddeck_lol [list [list "\#flashcards.Flashcards\#" \
				"\#flashcards.Description\#" ]]
    set carddeck_attrs_list [list border 1]
    if { [llength $stack_lol] > 0 } {
	foreach stack_list $stack_lol {
	    set id [lindex $stack_list 0]
	    set name_arr(${id}) [lindex $stack_list 1]
	    set descr_arr(${id}) [lindex $stack_list 2]
	    set row_list [list "<a href="card?stack_id=${id}">$name_arr(${id})</a>" $descr_arr(${id}) ]
	    lappend carddeck_lol $row_list
	}
    } else {
	lappend carddeck_lol [list "\#flashcards.None\#" ""]
    }
    
    set avail_decks_html [qss_list_of_lists_to_html_table $carddeck_lol $carddeck_attrs_list]
    append content_html <br> <br> "<h3>Available decks</h3>" \n $avail_decks_html \n
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

    set table_html [qss_list_of_lists_to_html_table $table_lol $table_attrs_list]

    append content_html <br> <br> "<h3>Your history</h3>" \n $table_html \n
} else {
    append content_html "\#flashcards.permission_denied\#"
}


