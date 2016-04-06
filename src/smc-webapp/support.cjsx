###############################################################################
#
# SageMathCloud: A collaborative web-based interface to Sage, IPython, LaTeX and the Terminal.
#
#    Copyright (C) 2016, SageMath, Inc.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

underscore = require('underscore')
{React, ReactDOM, Actions, Store, rtypes, rclass, Redux, redux, COLOR}  = require('./smc-react')
{Col, Row, Button, Input, Well, Alert, Modal} = require('react-bootstrap')
{Icon, Loading, SearchInput, Space, ImmutablePureRenderMixin} = require('./r_misc')
misc            = require('smc-util/misc')
misc_page       = require('./misc_page')
{top_navbar}    = require('./top_navbar')
{salvus_client} = require('./salvus_client')
{HelpEmailLink, SiteName} = require('./customize')

class SupportStore extends Store


class SupportActions extends Actions

    get_store: =>
        @redux.getStore('support')

    get: (key) =>
        @get_store().get(key)

    reset: =>
        @init_email_address()
        @setState
            state   : ''
            err     : ''

    show: (show) =>
        if show
            @reset()
        @setState
            show     : show

    new_ticket: (evt) =>
        evt?.preventDefault()
        @reset()

    init_email_address: () =>
        account  = @redux.getStore('account')
        email    = account.get_email_address()
        @set_email(email)

    set_email: (email) =>
        @setState(email: email)
        if misc.is_valid_email_address(email)
            @setState(email_err : null)
        else
            @setState(email_err : "Email address invalid!")

    valid: () =>
        s = @get('subject')?.trim() isnt ''
        b = @get('body')?.trim() isnt ''
        e = not @get('email_err')?
        return s and b and e

    project_id : ->
        pid = top_navbar.current_page_id
        if misc.is_valid_uuid_string(pid)
            return pid
        else
            return null

    projects : =>
        @redux.getStore("projects")

    project_title : ->
        if @project_id()?
            return @projects().get_title(@project_id())
        else
            return null

    location : ->
        window.location.pathname.slice(window.smc_base_url.length)

    # sends off the support request
    support: () =>
        store    = @get_store()
        account  = @redux.getStore('account')
        project_id = @project_id()

        if misc.is_valid_uuid_string(project_id)
            project  = @redux.getProjectActions(project_id)
            upgrades = @projects().get_upgrades_to_project(project_id)
            console.log("PID", project, upgrades)
        else
            project  = undefined
            upgrades = undefined

        tags = []
        # TODO use this to add 'member' or 'free'
        account.get_total_upgrades()
        # tags.push(if TEST then 'member' else 'free')

        @setState
            state   : 'creating'

        info = {} # additional data dict, like browser/OS

        salvus_client.create_support_ticket
            opts:
                username     : account.get_fullname()
                email_address: account.get_email_address()
                subject      : store.get('subject')
                body         : store.get('body') # TODO markdown2html
                tags         : tags
                project_id   : project_id
                location     : @location()
                info         : info
            cb : @process_support

    process_support: (err, url) =>
        console.log("callback process_support:", err, url)
        if not err?
            @setState    # only clear subject/boy, if there has been a success!
                subject  : ''
                body     : ''
                url      : url
        @setState
            state  : if err? then 'error' else 'created'
            err    : err ? ''


SupportInfo = rclass
    displayName : 'Support-info'

    propTypes :
        actions      : rtypes.object.isRequired
        state        : rtypes.string.isRequired
        url          : rtypes.string.isRequired
        err          : rtypes.string.isRequired

    error : () ->
        <Alert bsStyle='danger' style={fontWeight:'bold'}>
            <p>
            Sorry, there has been an error creating the ticket.
            Please email <HelpEmailLink /> directly!
            </p>
            <p>Error message:
            <pre>{@props.err}</pre>
            </p>
        </Alert>

    created : () ->
        if @props.url?.length > 1
            url = <a href={@props.url} target='_blank'>{@props.url}</a>
        else
            url = 'no ticket'
        <div style={textAlign:'center'}>
          <p>
              Ticket has been created successfully.
              Save this link for future reference:
          </p>
          <p style={fontSize:'120%'}>{url}</p>
          <Button bsStyle='success'
              style={marginTop:'3em'}
              onClick={@props.actions.new_ticket}>Create New Ticket</Button>
       </div>

    default : () ->
        title = @props.actions.project_title()
        if title?
            what = "the current project \"#{title}\""
        else
            what = <code>{@props.actions.location()}</code>
        <div>
            <p>
                You have a problem with {what}?
                Tell us about it by creating a support ticket.
            </p>
            <p>
                After successfully submitting it,
                you{"'"}ll receive a ticket number and a link to the ticket.
                Keep it to stay in contact with us!
            </p>
        </div>

    render : ->
        switch @props.state
            when 'error'
                return @error()
            when 'creating'
                return <Loading />
            when 'created'
                return @created()
            else
                return @default()

SupportFooter = rclass
    displayName : 'Support-footer'

    propTypes :
        close    : rtypes.func.isRequired
        submit   : rtypes.func.isRequired
        show_form: rtypes.bool.isRequired
        valid    : rtypes.bool.isRequired

    render : ->
        if @props.show_form
            btn = <Button bsStyle='primary'
                          onClick={@props.submit}
                          disabled={not @props.valid}>
                       <Icon name='medkit' /> Get Support
                   </Button>
        else
            btn = <span/>

        <Modal.Footer>
            <Button bsStyle='default' onClick={@props.close}>Close</Button>
            {btn}
        </Modal.Footer>

SupportForm = rclass
    displayName : 'Support-form'

    getDefaultProps : ->
        show        : true
        email_err   : ''

    propTypes :
        email     : rtypes.string.isRequired
        email_err : rtypes.string
        subject   : rtypes.string.isRequired
        body      : rtypes.string.isRequired
        show      : rtypes.bool.isRequired
        submit    : rtypes.func.isRequired
        actions   : rtypes.object.isRequired

    ###
    shouldComponentUpdate: (nextProps, nextState) =>
        e = @props.email != nextProps.email
        s = @props.subject != nextProps.subject
        b = @props.body != nextProps.body
        return e or s or b
    ###

    email_change  : ->
        @props.actions.set_email(@refs.email.getValue())

    data_change : ->
        @props.actions.setState
            body     : @refs.body.getValue()
            subject  : @refs.subject.getValue()

    render : ->
        if not @props.show
            return <div />

        alert = if @props.email_err?.length > 0
            <Alert bsStyle='danger'>
                 <div>{@props.email_err}</div>
            </Alert>

        <form>
            <Input
                label       = 'You email address'
                ref         = 'email'
                type        = 'text'
                placeholder = 'your_email@address.com'
                bsStyle     = {if ee? then 'warning'}
                value       = {@props.email}
                onChange    = {@email_change} />
            {alert if alert?}
            <Input
                ref         = 'subject'
                autoFocus
                type        = 'text'
                label       = 'Message'
                placeholder = "Subject ..."
                value       = {@props.subject}
                onChange    = {@data_change} />
            <Input
                ref         = 'body'
                type        = 'textarea'
                placeholder = 'Describe the problem ...'
                rows        = 6
                value       = {@props.body}
                onChange    = {@data_change} />
        </form>


Support = rclass
    displayName : 'Support-main'

    mixins: [ImmutablePureRenderMixin]

    propTypes :
        actions : rtypes.object.isRequired

    getDefaultProps : ->
        show        : false
        email       : ''
        subject     : ''
        body        : ''
        state       : ''
        url         : ''
        err         : ''
        email_err   : ''

    reduxProps :
        support:
            show         : rtypes.bool
            email        : rtypes.string
            subject      : rtypes.string
            body         : rtypes.string
            state        : rtypes.string # '' ←→ {creating → created|error}
            url          : rtypes.string
            err          : rtypes.string
            email_err    : rtypes.string

    open : ->
        @props.actions.show(true)

    close : ->
        @props.actions.show(false)

    submit : (event) ->
        event?.preventDefault()
        @props.actions.support()

    valid : () ->
        @props.actions.valid()

    render : () ->
        show_form = false

        if (not @props.state?) or @props.state == ''
            show_form = true

        <Modal show={@props.show} onHide={@close}>
            <Modal.Header closeButton>
                <Modal.Title>Support Ticket</Modal.Title>
            </Modal.Header>

            <Modal.Body>
                <SupportInfo
                    actions   = {@props.actions}
                    state     = {@props.state}
                    url       = {@props.url}
                    err       = {@props.err} />
                <SupportForm
                    actions   = {@props.actions}
                    email     = {@props.email}
                    email_err = {@props.email_err}
                    subject   = {@props.subject}
                    body      = {@props.body}
                    show      = {show_form}
                    submit    = {(e) => @submit(e)} />
            </Modal.Body>

            <SupportFooter
                    show_form       = {show_form}
                    close           = {=> @close()}
                    submit          = {(e) => @submit(e)}
                    valid           = {@valid()} />
        </Modal>

render = (redux) ->
    store   = redux.getStore('support')
    actions = redux.getActions('support')

    <Redux redux={redux}>
        <Support actions = {actions} />
    </Redux>

render_project_support = (dom_node, redux) ->
    ReactDOM.render(render(redux), dom_node)

unmount = unmount = (dom_node) ->
    ReactDOM.unmountComponentAtNode(dom_node)

init_redux = (redux) ->
    if not redux.getActions('support')?
        redux.createActions('support', SupportActions)
        redux.createStore('support', SupportStore, {})
init_redux(redux)

# hooking this up to the website
$support = $('#smc-top_navbar-support')
$targ = $support.find('.react-target')
render_project_support($targ[0], redux)
$support.find("a").click () ->
    # path = that.editor?.active_tab?.filename ? ''
    redux.getActions('support').show(true)
