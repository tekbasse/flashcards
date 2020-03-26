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
set page_mode_list [list "frontside" "backside" "index"]


if { !$read_p } {
    append content_html "\#flashcards.permission_denied\#"
} else {
    
    # defaults
    set field_list [list stack_id deck_id card_id content_id page flip skip pop keep back_value back_title front_value front_title]
    foreach f $field_list {
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
    # Used to build form
    set f_lol [list ]
    
    set form_submitted_p [qf_get_inputs_as_array input_array]
    
    if { $form_submitted_p } {
	# Get possible inputs
	ns_log Notice "flashcards/www/index.tcl.45 input_array '[array get input_array ]"
	if { [qf_is_natural_number $input_array(stack_id) ] } {
	    set stack_id $input_array(stack_id)
	}
	if { [qf_is_natural_number $input_array(deck_id) ] } {
	    set deck_id $input_array(deck_id)
	}
	if { [qf_is_natural_number $input_array(card_id) ] } {
	    set card_id $input_array(card_id)
	}
	if { $input_array(page) in $page_mode_list } {
	    set page $input_array(page)
	}
	if { $input_array(flip) ne "" } {
	    set flip_p 1
	}
	if { $input_array(skip) ne "" } {
	    set skip_p 1
	}
	if { $input_array(pop) ne "" } {
	    set pop_p 1
	}
	if { $input_array(keep) ne "" } {
	    set keep_p 1
	}
	
	# Determine mode, set mode to: index, frontside, backside
	if { $skip_p || $pop_p || $keep_p || ( $page eq "frontside" && $stack_id ne "")  } {
	    set mode "frontside"
	} elseif { $flip_p && $card_id ne "" && $stack_id ne "" } {
	    set mode "backside"
	}
    }

    # Common to more than one mode:
    set stacks_lol [db_list_of_lists flc_stack_r {
	select stack_id, content_id, name, description, card_count
	from flc_card_stack
	where instance_id=:instance_id
	order by stack_id asc } ]

    set card_title_arr(a) "\#flashcards.Abbreviation\#"
    set card_title_arr(t) "\#flashcards.Term\#"
    set card_title_arr(d) "\#flashcards.Description\#"

    # Determine if displaying front or back side of card.
    # and mode of display.
    ns_log Notice "flashcards/www/index.tcl.88: mode '${mode}' "
    # implement mode via switch, which sets  up page and parameters for form.
    switch -exact -- $mode {
	index {

	    # make a radio form 
	    # for new ones, and for user history cases that are not complete.
	    # with a start button

	    set active_lol [db_list_of_lists flc_user_stats_r {
		select stack_id,
		time_start,
		deck_id,
		cards_completed_count
		from flc_user_stats 
		where instance_id=:instance_id 
		and user_id=:user_id
		and time_end is null
		order by time_start desc } ]

	    # Make this a radio list:
	    set carddeck_lol [list ]
	    set attr_lol [list ]
	    if { [llength $stacks_lol] > 0 } {

		foreach stack_list $stacks_lol {
		    lassign $stack_list id c_id name_arr(${id}) descr_arr(${id}) card_ct_arr(${id})
		    # Make a radio list item with a label
		    # if new: stack, description (make a new deck)
		    # if incomplete: stack, started x, continue

		    # First, new stacks
		    set row_list [list \
				      value ${id} label \
				      "$name_arr(${id})(ref${id}): $descr_arr(${id})" ]
		    lappend attr_lol $row_list
		}
	    }
	    if {  [llength $active_lol] > 0 } {
		ns_log Notice "active_lol '$active_lol'"
		#  add unfinished cases to attr_lol
		foreach active_list $active_lol {
		    lassign $active_list id time_start deck_id cards_completed_count
		    set row_list [list value ${deck_id} label "$name_arr(${id})(ref${deck_id}): Started ${time_start}, Done: (${cards_completed_count}/$card_ct_arr(${id})" ]
		    lappend attr_lol $row_list
		}
	    }
	    if { [llength $attr_lol ] > 0 } {
		set row_list [list type radio name stack_id value $attr_lol ]
		lappend f_lol $row_list
		set row_list [list type submit name start value "\#flashcards.Start\#" datatype text label ""]		
		lappend f_lol $row_list
		set row_list [list type hidden name page value frontside label "" ]
		lappend f_lol $row_list
	    } else {
		set form_html "\#flashcards.None\#"
	    }

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
		and time_end is not null
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
	    if { [llength $history_lol] < 1 } {
		set row_list [list "\#flashcards.None\#" "" "" "" "" "" ]
		lappend table_lol $row_list
	    } else {    
		foreach history_list $history_lol {
		    
		    set stack_id [lindex $history_list 0]
		    set name $name_arr(${stack_id})
		    
		    set row_list [lreplace $history_list 0 0 $name]
		    lappend table_lol $row_list
		}
	    }
	    
	    set table_html [qss_list_of_lists_to_html_table \
				$table_lol \
				$table_attrs_list]
	    
	    set content_part2_html "<br><br><h3>Your history</h3>${table_html}"
	    
	}
	frontside {
	    ns_log Notice "flashcards/www/index.tcl.194 stack_id '$stack_id' deck_id '$deck_id' instance_id '$instance_id' user_id '$user_id'"
	    if { $stack_id ne "" && $deck_id eq "" } {
		ad_progress_bar_begin -title "Making a shuffled deck" -message_1 "Shuffling..." -message_2 "Please wait.. Page will continue loading momentarily.."
		# Start a new deck.
		#wrap in db_transaction
		set deck_id [db_nextval flc_id_seq]
		# Populate flc_user_stack
		# get/shuffle list of card_id
		set card_id_list [db_list flc_card_stack_card_rN5 {
		    select card_id from flc_card_stack_card
		    where instance_id=:instance_id and
		    stack_id=:stack_id} ]
		set card_id_shuffled_list [acc_fin::shuffle_list $card_id_list ]
		# then:
		set order_id 0
		set count 1
		set factor [llength $card_id_shuffled_list ]
		foreach card_id $card_id_shuffled_list {
		    db_dml flc_user_stack_c3 { insert into flc_user_stack
			(deck_id,card_id,order_id,instance_id,user_id)
			values (:deck_id,:card_id,:order_id,:instance_id,:user_id)
		    }
		    incr order_id $factor
		    incr count
		}
		# Populate flc_user_stats
		set time_start [qf_clock_format [clock seconds]]
		db_dml flc_user_stats_c3 { insert into flc_user_stats
		    (stack_id,deck_id,time_start,cards_completed_count,cards_remaining_count,user_id,instance_id)
		    values (:stack_id,:deck_id,:time_start,'0',:count,:user_id,:instance_id)
		    
		}
		set card_id [lindex $card_id_shuffled_list 0]
	    }
	    
	    # increase view_count
	    set view_count ""
	    ns_log Notice "flashcards/www/index.tcl instance_id '$instance_id' user_id '$user_id' deck_id '$deck_id' card_id '$card_id'"
	    db_1row flc_user_stack_r4 { select view_count
		from flc_user_stack where
		instance_id=:instance_id and
		user_id=:user_id and
		deck_id=:deck_id and
		card_id=:card_id and
		(done_p !='t' or done_p is null) }
	    if { $view_count eq "" } {
		set view_count 0
	    }
	    incr view_count
	    db_dml flc_user_stack_u0 { update flc_user_stack
		set view_count=:view_count where
		instance_id=:instance_id and
		user_id=:user_id and
		deck_id=:deck_id and
		card_id=:card_id and
		( done_p !='t' or done_p is null) }
	    
	    # If there is a 'pop' or 'keep' answer from backside,
	    # record it before rendering next frontside page.
	    if { $pop_p } {
		# remove the card from the deck
		db_dml flc_user_stack_u1 { update flc_user_stack
		    set done_p = 't' where
		    instance_id=:instance_id and
		    deck_id=:deck_id and
		    card_id=:card_id and
		    user_id=:user_id }
	    }
	    if { $keep_p } {
		# Put the card back in the deck, in a random place.
		# Get current order_id 
		db_1row { select order_id
		    from flc_user_stack
		    where instance_id=:instance_id and
		    deck_id=:deck_id and
		    card_id=:card_id and
		    user_id=:user_id and
		    ( done_p!='t' or done_p is null ) }
		# Get last order_id in deck.
		# It may be the same as the current one.
		db_1row flc_user_stack_r1b {
		    select max( order_id) as order_id_last
		    from flc_user_stack
		    where instance_id=:instance_id and
		    deck_id=:deck_id and
		    user_id=:user_id and
		    ( done_p!='t' or done_p is null ) }
		# choose a random number inbetween
		set order_diff [expr { $order_id_last - $order_id } ]
		set order_id_new [randomRange $order_diff]
		incr order_id_new
		# assign current card to new number
		db_dml flc_user_stack_u2 { update flc_user_stack
		    set order_id=:order_id_new where
		    instance_id=:instance_id and
		    deck_id=:deck_id and
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
		deck_id=:deck_id and
		( done_p!='t' or done_p is null )
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
		    card_id=:card_id }
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
		append content_html "<div class=\"l-grid-third padded\"><div class=\"padded-inner content-box\">"
		append content_html "<div style=\"border:solid; border-width:1px; padding: 1px; margin: 2px; width: 100%\">"
		append content_html "<pre>\#flashcards.Frontside\#</pre>"
		append content_html "<h1>$card_title_arr(${front_ref})</h1>\n"
		append content_html "<p><strong>$content_arr(${front_ref})</strong></p>"
		append content_html "<br><br>"
		append content_html "</div>"
		append content_html "<br><br>"
				append content_html "<div style=\"border:solid; border-width:1px; padding: 1px; margin: 2px; width: 100%\">"
		append content_html "<h2>\#flashcards.Backside\#</h2>"
		append content_html "<p><strong>$card_title_arr(${back_ref})</strong></p>"
		append content_html "<h3>\#flashcards.Flip_over_to_see\#</h3>"
		append content_html "</div>"http://dfcb.github.io/extra-strength-responsive-grids/img/resize.png http://dfcb.github.io/extra-strength-responsive-grids/img/resize.png 
		# Add the button choices as a form.
		set f_lol [list \
			       [list type hidden name stack_id value ${stack_id} label ""] \
			       [list type hidden name content_id value ${content_id} label "" ] \
			       [list type hidden name card_id value ${card_id} label "" ] \
			       [list type hidden name back_value value "$content_arr(${back_ref})" label "" ] \
			       [list type hidden name back_title value "$card_title_arr(${back_ref})" label "" ] \
			       [list type hidden name front_value value "$content_arr(${front_ref})" label "" ] \
			       [list type hidden name front_title value "$card_title_arr(${front_ref})" label "" ] \
			       [list type submit name skip \
				    value "\#flashcards.Skip\#" datatype text title "\#flashcards.Skip__pass\#" label "" style "class: btn; float: left;"] \
			       [list type submit name flip \
				    value "\#flashcards.Flip\#" datatype text title "\#flashcards.Flip_over\#" label "" style "class: btn; float: right;"] \
			      ]
		append content_part2_html "</div></div>"
	    }
	}
	backside {
	    # additional input validation for this mode
	    if { [qf_is_natural_number $input_array(content_id) ] } {
		set content_id $input_array(content_id)
	    }
	    if { [hf_are_safe_textarea_characters_q $input_array(back_value) ] } {
		set back_value $input_array(back_value)
	    }
	    if { [hf_are_safe_textarea_characters_q $input_array(back_title) ] } {
		set back_title $input_array(back_title)
	    }
	    if { [hf_are_safe_textarea_characters_q $input_array(front_value) ] } {
		set back_value $input_array(front_value)
	    }
	    if { [hf_are_safe_textarea_characters_q $input_array(front_title) ] } {
		set back_title $input_array(front_title)
	    }
	    # display back card,
	    #    requires:
	    #         stack_id, content_id, card_id, back_value, back_title, front_value, front_title
	    # These values should already have been passed
	    # via mode: frontside
	    
	    append content_html "<pre>\#flashcards.Frontside\#</pre>"
	    append content_html "<h1>$front_title</h1>\n"
	    append content_html "<p><strong>$front_value</strong></p>"
	    append content_html "<br><br>"
	    append content_html "<div style=\"border:solid; border-width:1px; padding: 1px; margin: 2px; width: 100%\">"
	    append content_html "<br>"
	    append content_html "<h2>\#flashcards.Backside\#</h2>"
	    append content_html "<p><strong>${back_value}</strong></p>"
	    
	    #    user options:
	    #                 Keep put/push back in stack
	    #                 Pop from stack
	    # Add the button choices as a form.
	    set f_lol [list \
			   [list type hidden name stack_id value ${stack_id} label ""] \
			   [list type hidden name card_id value ${card_id} label "" ] \
			   [list type submit name skip \
				value "\#flashcards.Keep\#" datatype text title "\#flashcards.Keep_in_stack\#" label "" style "class: btn; float: left;"] \
			   [list type submit name flip \
				value "\#flashcards.Pop\#" datatype text title "\#flashcards.Pop_from_stack\#" label "" style "class: btn; float: right;"] \
			  ]
	    
	}
    }


    # build form
    # if f_lol, is empty, skip building a form.
    
    if { [llength $f_lol ] > 0 } {
	#  append form_html if it already exists.
	append content_html $form_html
	set form_html ""
	
	::qfo::form_list_def_to_array \
	    -list_of_lists_name f_lol \
	    -fields_ordered_list_name qf_fields_ordered_list \
	    -array_name f_arr \
	    -ignore_parse_issues_p 0
	
	set validated_p [qfo_2g \
			     -form_id 20200325 \
			     -fields_ordered_list $qf_fields_ordered_list \
			     -fields_array f_arr \
			     -inputs_as_array input_array \
			     -form_submitted_p $form_submitted_p \
			     -form_varname form_html ]
	
	append content_html $form_html
    }
    
    # append content_part2_html if it already exists.
    if { [info exists content_part2_html ] } {
	append content_html $content_part2_html
    }
}

