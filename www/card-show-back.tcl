
set error_p 0
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
    set input_array(stack_id) ""
    set input_array(card_id) ""
    # For logic dependency
    set stack_id ""
    set frontside_p "1"
    set card_id ""
    
    set form_submitted_p [qf_get_inputs_as_array input_array]
    if { $form_submitted_p } {
	# Get possible inputs
	set frontside_p [qf_is_true $input_array(frontside_p) 1]
	if { [qf_is_natural_number $input_array(stack_id) ] } {
	    set stack_id $input_array(stack_id)
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
	ns_log Notice "flashcards/www/card-show.tcl L58 stack_id_found_p '${stack_id_found_p}'"	
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
	lappend user_message_list "Missing card deck info. Browse <a href=\"index\">here</a> to try again. (Ref.68)"
	set error_p 1
    } else {
ns_log Notice "flashcards/www/card-show.tcl L76: frontside_p '$frontside_p'"
	if { $frontside_p } {
	    # Determine if displaying front or back side of card.
	    # and mode of display.
	    # modes:
	    # display first frontside of card this session,
	    #    requries:
	    #        stack_id, card_id(optional,but default)
	    #    user options: skip/pass 
	    #                  flip (to see backside) via form
	    
	    # display frontside of card
	    # after recording answer from last "backside" form post.
	    #    requires
	    #        stack_id, card_id (last)
	    #    system obtains next card_id
	    #    user options: skip/pass 
	    #                  flip (to see backside) via form

	    set f_lol [list \
			   [list type submit name skip value "\#flashcards.Skip\#" datatype text label "" title "\#flashcards.Skip__pass\#" ] \
			   [list type submit name flip value "\#flashcards.Flip\#" datatype text label "" title "\#flashcards.Flip_over\#" ]
		      ]


	    ::qfo::form_list_def_to_array \
		-list_of_lists_name f_lol \
		-fields_ordered_list_name qf_fields_ordered_list \
		-array_name f_arr \
		-ignore_parse_issues_p 0
	    
	    set validated_p [qfo_2g \
				 -form_id 20200322 \
				 -fields_ordered_list $qf_fields_ordered_list \
				 -fields_array f_arr \
				 -inputs_as_array input_array\
				 -form_submitted_p $form_submitted_p \
				 -form_varname form_html ]
	    if { $validated_p } {


		
	    } elseif { $card_id ne "" } {
ns_log Notice "flashcards/www/card-show.tcl L119. Display back card."
		# display back card,
		#    requires:
		#         stack_id, card_id, frontside_p == 0
		#    user options:
		#                 Put/Push back in stack
		#                 Pop from stack
		
		


	    } else {
		lappend user_message_list "Missing card_id. (Ref.102) Error logged and will be investigated."
		ns_log Warning "flashcards/www/card-show.tcl:103 No card_id for frontside_p '0' stack_id '${stack_id}' user_id '${user_id}'. "
		set error_p 1
	    }
	    
	    if { !$frontside_p } {
		set title "\#flashcards.Backside\#"
	    }

	    
	}
    }
    
    if { $error_p } {
	foreach user_message $user_message_list {
	    append user_message_html "<li>${user_message}</li>"
	}
    }

}
set context [list [list index "\#flashcards.Flashcards\#"] $title]
