ns_log Notice "/flashcards/www/index.tcl New page start   * * * * * * * * * *"
set title "#flashcards.Flashcards#"
set context [list $title]
set user_id [ad_conn user_id]
set instance_id [ad_conn package_id]
set read_p [permission::permission_p \
                -party_id $user_id \
                -object_id $instance_id \
                -privilege read]

set error_p 0
# adp required values for all cases
set form_html ""
set content_html ""
set mode ""

set user_message_list [list ]
set user_message_html ""
# page is the target switch expected to be triggered this time
set page_mode_list [list "frontside" "backside" "index" "newdeck"]
# frompage is the switch that was triggered last time
set frompage_mode_list $page_mode_list
# Sometimes a switch will have be determined based on the input
# from the frompage, so page with be empty in those cases.

if { !$read_p } {
    append content_html "\#flashcards.permission_denied\#"
} else {
    
    # defaults
    set field_list [list stack_id deck_id card_id content_id page flip skip pop keep back_value back_title front_value front_title frompage]
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
    ns_log Notice "flashcards/www/index.tcl.47 input_array '[array get input_array ]"
    if { $form_submitted_p } {
        # Get possible inputs
        ns_log Notice "flashcards/www/index.tcl.50 input_array '[array get input_array ]"
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
        if { $input_array(frompage) in $frompage_mode_list } {
            set frompage $input_array(frompage)
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
        
        if { $deck_id eq "" && $stack_id ne "" } {
            # First we must determine if stack_id is a stack_id or deck_id
            # from index (where both are referred to as stack_id in
            # the radio buttons.
            # This fixes stack_id/deck_id misassignments
            ns_log Notice "/flashcards/index.87 stack_id '${stack_id}'"
            set stack_id_orig $stack_id
            set maybe_deck_id_p [db_0or1row flc_user_stats_r5 {
                select stack_id, deck_id
                from flc_user_stats where
                ( deck_id=:stack_id or
                  stack_id=:stack_id ) and
                user_id=:user_id and
                instance_id=:instance_id limit 1 } ]

            # if !$maybe_deck_id_p then must be stack_id, do nothing
            
            if { $stack_id == $stack_id_orig } {
                # remove dangling id
                set deck_id ""
            }
            ns_log Notice "/flashcards/index.103 stack_id '${stack_id}' deck_id '${deck_id}' maybe_deck_id_p '$maybe_deck_id_p'"
        }

        # frontside and backside require deck_id and card_id
        # newdeck requires stack_id
        # index requires neither
        
        ns_log Notice "/flashcards/index.tcl.100 skip_p '$skip_p' flip_p '$flip_p' pop_p '$pop_p' keep_p '$keep_p' page '$page' stack_id '$stack_id' deck_id '$deck_id' card_id '$card_id'"
        
        # Determine if displaying front or back side of card.
        # and mode of display. ie
        # Determine mode, set mode to: index, frontside, backside, or newdeck
        if { $skip_p || $pop_p || $keep_p || $page eq "frontside"  } {
            if { $deck_id ne "" } {
                set mode "frontside"
            } else {
                set mode "newdeck"
                if { $frompage eq $mode } {
                    set mode "frontside"
                    ns_log Warning "/flashcards/index.tcl.112 Tried to assign a newdeck to a newdeck. Re-assigning to 'frontside'"
                } elseif { $frompage eq "frontside" } {
                    ns_log Notice "/flashcards/index.tcl.114 Frontside must have completed the deck."
                    set mode "index"
                }
            }
        } elseif { $flip_p && $card_id ne "" && $deck_id ne "" } {
            set mode "backside"
        }
    }
    ns_log Notice "flashcards/www/index.tcl.119: mode '${mode}' "
    
    # Common to more than one mode:
    set stacks_lol [db_list_of_lists flc_card_stack_r {
        select stack_id, content_id, name, description, card_count
        from flc_card_stack
        where instance_id=:instance_id
        order by stack_id asc } ]

    set card_title_arr(a) "\#flashcards.Abbreviation\#"
    set card_title_arr(t) "\#flashcards.Term\#"
    set card_title_arr(d) "\#flashcards.Description\#"


    # implement mode via switch, which sets  up page and parameters for form.
    ns_log Notice "/flashcards/www/index.tcl.134 start $mode"
    switch -exact -- $mode {
        index {

            # make a radio form 
            # for new ones, and for user history cases that are not complete.
            # with a start button

            #TODO THe radio button should default to the most recent created
            # deck from flc_user_stats
            
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
                    lassign $stack_list s_id c_id name_arr(${s_id}) descr_arr(${s_id}) card_ct_arr(${s_id})
                    # Make a radio list item with a label
                    # if new: stack, description (make a new deck)
                    # if incomplete: stack, started x, continue

                    # First, new stacks
                    set row_list [list \
                                      value ${s_id} label \
                                      "$name_arr(${s_id})(ref${s_id}): $descr_arr(${s_id})" ]
                    lappend attr_lol $row_list
                }
            }
            if {  [llength $active_lol] > 0 } {
                ns_log Notice "/flashcards/index.tcl.172 active_lol '$active_lol'"
                #  add unfinished cases to attr_lol
                foreach active_list $active_lol {
                    lassign $active_list s_id time_start deck_id cards_completed_count
                    set row_list [list value ${deck_id} label "$name_arr(${s_id})(ref${deck_id}): Started ${time_start}, Done: (${cards_completed_count}/$card_ct_arr(${s_id}))" ]
                    lappend attr_lol $row_list
                }
            }
            if { [llength $attr_lol ] > 0 } {

                append content_html "<p>\#flashcards.Choose_a_deck\#</p>"
                
                set row_list [list type radio name stack_id value $attr_lol ]
                lappend f_lol $row_list
                set row_list [list type submit name start value "\#flashcards.Start\#" datatype text label "" title "\#flashcards.Start_reading_flashcards_\#" class "btn-big" style "padding: 35px;"]
                lappend f_lol $row_list
                set row_list [list type hidden name frompage value index ]
                set row_list [list type hidden name page value frontside ]
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
        newdeck {
            ns_log Notice "flashcards/www/index.tcl.237 instance_id '$instance_id' user_id '$user_id' stack_id '$stack_id' deck_id '$deck_id' card_id '$card_id'"
            
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

            set frompage newdeck
            #ad_returnredirect "/flashcards/index?card_id=${card_id}&stack_id=${stack_id}&deck_id=${deck_id}&page=${page}&frompage=${frompage}"
            #ad_script_abort
            set f_lol [list \
                           [list type hidden name card_id value ${card_id} ] \
                           [list type hidden name stack_id value ${stack_id} ]\
                           [list type hidden name deck_id value ${deck_id} ] \
                           [list type hidden name page value "frontside" ] \
                           [list type hidden name frompage value $frompage ] \
                           [list type submit name submit value "\#flashcards.Start\#" datatype text label "" style "float: left;padding: 35px;" class "btn-big"] \
                          ]
            ns_log Notice "flashcards/www/index.tcl.281 instance_id '$instance_id' user_id '$user_id' stack_id '$stack_id' deck_id '$deck_id' card_id '$card_id'"

        }
        frontside {
            
            # increase view_count
            set view_count ""
            ns_log Notice "flashcards/www/index.tcl.289 instance_id '$instance_id' user_id '$user_id' stack_id '$stack_id' deck_id '$deck_id' card_id '$card_id'"
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
            if { $pop_p || $skip_p } {
                # update flc_user_stats
                db_1row flc_card_stack_r21 {
                    select card_count as total_card_count
                    from flc_card_stack where
                    stack_id=:stack_id and
                    instance_id=:instance_id }
                    
                db_1row flc_user_stack_r10 {
                    select sum(view_count) as sum_view_count
                    from flc_user_stack where
                    deck_id=:deck_id and
                    user_id=:user_id and
                    instance_id=:instance_id }
                db_1row flc_user_stack_r12 {
                    select count(card_id) as cards_completed_count
                    from flc_user_stack where
                    done_p='t' and
                    deck_id=:deck_id and
                    user_id=:user_id and
                    instance_id=:instance_id }
                set repeats_count [expr { $sum_view_count - $total_card_count } ]
                set cards_remaing_count [expr { $total_card_count - $cards_completed_count } ]

                db_dml flc_user_stack_u6 { update flc_user_stats
                    set cards_remaining_count=:cards_remaing_count,
                    cards_completed_count=:cards_completed_count,
                    repeats_count=:repeats_count where
                    user_id=:user_id and
                    instance_id=:instance_id and
                    deck_id=:deck_id }

            }
            
            
            if { $keep_p || $skip_p } {
                # Put the card back in the deck, in a random place.
                # Get current order_id 
                db_1row flc_user_stack_r6 { select order_id
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
                set time_end [qf_clock_format [clock seconds]]
                db_1row flc_card_stack_r23 {
                    select card_count as total_card_count
                    from flc_card_stack where
                    stack_id=:stack_id and
                    instance_id=:instance_id }

                db_1row flc_user_stack_r11 {
                    select sum(view_count) as sum_view_count
                    from flc_user_stack where
                    deck_id=:deck_id and
                    user_id=:user_id and
                    instance_id=:instance_id }
                set repeats_count [expr { $sum_view_count - $total_card_count } ]
                db_dml flc_user_stack_u3 { update flc_user_stats
                    set time_end=:time_end,
                    cards_remaining_count='0',
                    cards_completed_count=:total_card_count,
                    repeats_count=:repeats_count where
                    user_id=:user_id and
                    instance_id=:instance_id and
                    deck_id=:deck_id }
                
                append content_html {
                    <div style="align:center;"><p><strong>#flashcards.Done_Congratulations_#</strong></p></div>}
                set f_lol [list \
                               [list type hidden name page value "index" ] \
                               [list type hidden name frompage value "frontside" ] \
                               [list type submit name submit value "\#flashcards.Finished\#" datatype text label "" style "float: left;padding: 35px;" class "btn-big" ] \
                              ]
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
                append content_html "<div style=\"border:solid; border-width:1px; padding: 4px; margin: 2px; width: 100%; word-wrap:normal;\">"
                append content_html "<pre>\#flashcards.Frontside\#</pre>"
                append content_html "<p>$card_title_arr(${front_ref})</p>\n"
                append content_html "<p><strong>$content_arr(${front_ref})</strong></p>"
                append content_html "<br><br>"
                append content_html "</div>"
                append content_html "<br><br>"
                append content_html "<div style=\"border:solid; border-width:1px; padding: 4px; margin: 2px; width: 100%; word-wrap:normal;\">"
                append content_html "<pre>\#flashcards.Backside\#</pre>"
                append content_html "<p><strong>$card_title_arr(${back_ref})</strong></p>"
                append content_html "<p><em>\#flashcards.Flip_over_to_see\#</em></p>"
                append content_html "</div>"
                # Add the button choices as a form.
                set f_lol [list \
                               [list type hidden name stack_id value ${stack_id} ] \
                               [list type hidden name content_id value ${content_id} ] \
                               [list type hidden name card_id value ${card_id} ] \
                               [list type hidden name deck_id value ${deck_id} ] \
                               [list type hidden name back_value value "$content_arr(${back_ref})" ] \
                               [list type hidden name back_title value "$card_title_arr(${back_ref})" ] \
                               [list type hidden name front_value value "$content_arr(${front_ref})" ] \
                               [list type hidden name front_title value "$card_title_arr(${front_ref})" ] \
                               [list type hidden name frompage value "frontside"] \
                               [list type submit name skip \
                                    value "\#flashcards.Skip\#" datatype text title "\#flashcards.Skip__pass\#" label "" style "float: left;padding: 35px;" class "btn-big" ] \
                               [list type submit name flip \
                                    value "\#flashcards.Flip\#" datatype text title "\#flashcards.Flip_over\#" label "" style "float: right;padding: 35px;" class "btn-big" ] \
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
                set front_value $input_array(front_value)
            }
            if { [hf_are_safe_textarea_characters_q $input_array(front_title) ] } {
                set front_title $input_array(front_title)
            }
            # display back card,
            #    requires:
            #         stack_id, content_id, card_id, back_value, back_title, front_value, front_title
            # These values should already have been passed
            # via mode: frontside
            
            append content_html "<div class=\"l-grid-third padded\"><div class=\"padded-inner content-box\">"
            append content_html "<div style=\"border:solid; border-width:1px; padding: 4px; margin: 2px; width: 100%; word-wrap:normal;\">"
            append content_html "<pre>\#flashcards.Frontside\#</pre>"
            append content_html "<p>${front_title}</p>\n"
            append content_html "<p><strong>${front_value}</strong></p>"
            append content_html "<br><br>"
            append content_html "</div>"
            append content_html "<br><br>"
            append content_html "<div style=\"border:solid; border-width:1px; padding: 4px; margin: 2px; width: 100%; word-wrap:normal;\">"
            append content_html "<pre>\#flashcards.Backside\#</pre>"
            append content_html "<p>${back_title}</p>"
            append content_html "<p><strong>${back_value}</strong></p>"
            append content_html "</div>"
            
            #    user options:
            #                 Keep put/push back in stack
            #                 Pop from stack
            # Add the button choices as a form.
            set form_submitted_p 0
            set f_lol [list \
                           [list type hidden name stack_id value ${stack_id} ] \
                           [list type hidden name deck_id value ${deck_id} ] \
                           [list type hidden name card_id value ${card_id} ] \
                           [list type hidden name frompage value "backside"] \
                           [list type hidden name page value "frontside"] \
                           [list type submit name keep \
                                value "\#flashcards.Keep\#" datatype text title "\#flashcards.Keep_in_stack\#" label "" style "float: left;padding: 35px;" class "btn-big"] \
                           [list type submit name pop \
                                value "\#flashcards.Pop\#" datatype text title "\#flashcards.Pop_from_stack\#" label "" style "float: right;padding: 35px;" class "btn-big" ] \
                          ]
            append content_part2_html "</div></div>"
        }
    }

    ns_log Notice "/flashcards/www/index.tcl.483 build form"
    # build form
    # if f_lol, is empty, skip building a form.
    ns_log Notice "/flashcards/www/index.tcl.486 f_lol '${f_lol}'"
    if { [llength $f_lol ] > 0 } {
        #  append form_html if it already exists.

        append content_html $form_html
        set form_html ""
        
        # Each newdeck,frontside, and backside form doesn't use
        # this level of input validation, so disable it
        # was: $frompage eq "newdeck"
        if { $mode in [list index frontside backside] || $frompage eq "newdeck" } {
            set form_submitted_p 0
            set validated_p 0
        }
        
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

