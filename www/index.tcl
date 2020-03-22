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

    foreach stack_list $stack_lol {
	set id [lindex $stack_list 0]
	set name_arr($id) [lindex $stack_list 1]
	set descr_arr($id) [lindex $stack_list 2]
    }

    set table_lol [list "#flashcards.Stack#" \
		       "#flashcards.Started#" \
		       "#flashcards.Finished#" \
		       "#flashcards.Completed#" \
		       "#flashcards.Remaining#" \
		       "#flashcards.Repeats#"]
    if { [llength $stats_lol] < 1 } {
	append table_lol [list "#flashcards.None#" "" "" "" "" ""]
    } else {	
	foreach stat_list $stats_lol {
	    
	    set stack_id [lindex $stat_list 0]
	    set name $name_arr(${stack_id})
	    set row_list [lreplace $stat_list 0 0 $name]
	    append table_lol $row_list
	}
    }
    set table_html [qss_list_of_lists_to_html_table $table_lol]

    append content_html $table_html
} else {
    append content_html "#flashcards.permission_denied#"
}



