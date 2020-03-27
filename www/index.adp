<if @mode@ ne "newdeck">
<master>
<property name="doc(title)">@title;noquote@</property>
<property name="context">@context;noquote@</property>
</if>
<if @user_message_html@ not nil>
<ul>
@user_message_html;noquote@
</ul>
</if>


@content_html;noquote@
