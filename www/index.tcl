set title "#flashcards.Flashcards#"
set context [list $title]
set user_id [ad_conn user_id]
set instance_id [ad_conn package_id]
set read_p [permission::permission_p \
		-party_id $user_id \
		-object_id $instance_id \
		-privilege read]
set content_html ""
if { $read_p } {

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
	    set row_list [list "<a href=\"card-show?stack_id=${id}\">$name_arr(${id})</a>" $descr_arr(${id}) ]
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


