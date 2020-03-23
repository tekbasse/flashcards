

set title ""
set form_html ""
set content_html ""

set user_id [ad_conn user_id]
set instance_id [ad_conn package_id]
set read_p [permission::permission_p \
		-party_id $user_id \
		-object_id $instance_id \
		-privilege read]

if { $read_p } {

    set form_submitted_p [qf_get_inputs_as_array input_array]
    if { $form_submitted_p } {
	set content_dat $input_array(content_dat)
	# Get possible inputs
    } else {
	# No references provided. # Let's guess at what is the next card and show it.
	# Log warning. This shouldn't happen.
    }
    # Determine if displaying front or back side of card.
    # and mode of display.
    # modes:
    # display first frontside of card this session,
    # display back card,
    # display frontside of card after recording answer from last "backside" form post

    if { $frontside_p } {
	set title "\#flashcards.Frontside\#"
    } else {
	set title "\#flashcards.Backside\#"
    }
    set context [list [list index "\#flashcards.Flashcards#"] $title]


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


