/* @flow */

import React, { Component } from 'react'
import {
  Image,
  View,
  StyleSheet,
  ActionSheetIOS,
  TouchableHighlight,
} from 'react-native'
import { Text, BOLD_FONT } from '../../../common/text'
import { LinkButton } from '../../../common/buttons'
import colors from '../../../common/colors'
import Images from '../../../images'
import Avatar from '../../../common/components/Avatar'
import { formattedDate } from '../../../utils/dateUtils'
import WebContainer from '../../../common/components/WebContainer'
import i18n from 'format-message'
import Navigator from '../../../routing/Navigator'

export type Props = {
  reply: DiscussionReply,
  depth: number,
  participants: { [key: string]: UserDisplay },
  courseID: string,
  discussionID: string,
  deleteDiscussionEntry: Function,
  replyToEntry: Function,
  myPath: number[],
  navigator: Navigator,
}

export default class Reply extends Component <any, Props, any> {

  showAttachment = () => {
    if (this.props.reply.attachment) {
      this.props.navigator.show('/attachment', { modal: true }, {
        attachment: this.props.reply.attachment,
      })
    }
  }

  render () {
    let { reply, depth, participants, courseID, discussionID, replyToEntry } = this.props
    participants = participants || {}
    let replies = reply.replies || []
    let childReplies = replies.map((r, i) => <Reply replyToEntry={replyToEntry} myPath={[...this.props.myPath, i]} deleteDiscussionEntry={this.props.deleteDiscussionEntry} courseID={courseID} discussionID={discussionID} participants={participants} reply={r} depth={depth + 1} key={r.id} navigator={this.props.navigator}/>)
    let user = participants[reply.user_id]

    if (reply.deleted) {
      return (<View style={{ height: 0 }} />)
    }

    return (
      <View style={style.parentRow}>

        <View style={style.colA}>
          {user &&
          <Avatar height={AVATAR_SIZE} key={user.id} avatarURL={user.avatar_image_url} userName={user.display_name} style={style.avatar}/> }
          {!user && <View style={style.avatar}/> }
          <View style={style.threadLine}/>
        </View>

        <View style={style.colB}>

          <View style={style.rowA}>
            {user && <Text style={style.userName}>{user.display_name}</Text>}
            <Text style={style.date}>{formattedDate(reply.updated_at)}</Text>
            <WebContainer scrollEnabled={false} style={{ flex: 1 }} html={reply.message}/>

            {reply.attachment &&
              <TouchableHighlight testID={`discussion-reply.${reply.id}.attachment`} onPress={this.showAttachment}>
                <View style={style.attachment}>
                  <Image source={Images.attachment} style={style.attachmentIcon} />
                  <Text style={style.attachmentText}>
                    {reply.attachment.display_name}
                  </Text>
                </View>
              </TouchableHighlight>
            }
            {this._renderButtons()}
          </View>

          <View style={style.rowB}>
            {childReplies}
          </View>
        </View>
      </View>
    )
  }

  _renderButtons = () => {
    return (
      <View style={style.footerContainer}>
       <LinkButton style={style.footer} textAttributes={{ color: colors.grey3 }} onPress={this._actionReply} testID='discussion.reply-btn'>
            {i18n('Reply')}
        </LinkButton>
        <Text style={[style.footer, { color: colors.grey3, textAlign: 'center', alignSelf: 'center' }]}>|</Text>
        <LinkButton style={style.footer} textAttributes={{ color: colors.grey3 }} onPress={this._actionEdit} testID='discussion.edit-btn'>
            {i18n('Edit')}
        </LinkButton>
      </View>
    )
  }

  _actionReply = () => {
    this.props.replyToEntry(this.props.reply.id, this.props.myPath)
  }
  _actionEdit = () => {
    const { courseID, discussionID } = this.props
    let options = []
    options.push(i18n('Delete'))
    options.push(i18n('Cancel'))
    ActionSheetIOS.showActionSheetWithOptions({
      options: options,
      cancelButtonIndex: options.length - 1,
      destructiveButtonIndex: options.length - 2,
    }, (button) => {
      if (button === (options.length - 1)) { return }
      if (button === (options.length - 2)) { this.props.deleteDiscussionEntry(courseID, discussionID, this.props.reply.id, this.props.myPath); return }
    })
  }
}

const AVATAR_SIZE = 24
const style = StyleSheet.create({
  parentRow: {
    flex: 1,
    flexDirection: 'row',
  },
  colA: {
    flexDirection: 'column',
    justifyContent: 'flex-start',
    alignItems: 'center',
    padding: 0,
    marginTop: 10,
    marginLeft: 10,
    marginRight: 10,
    flex: 0.1,
  },
  colB: {
    flex: 1,
  },
  rowA: {
    alignSelf: 'stretch',
    marginTop: global.style.defaultPadding / 1.25,
  },
  rowB: {
    flex: 1,
    alignSelf: 'stretch',
  },
  threadLine: {
    backgroundColor: colors.grey1,
    width: 1,
    flex: 1,
  },
  avatar: {
    height: AVATAR_SIZE,
    width: AVATAR_SIZE,
    borderRadius: AVATAR_SIZE / 2,
    backgroundColor: colors.grey1,
    marginTop: global.style.defaultPadding / 1.25,
  },
  userName: {
    fontSize: 14,
    fontWeight: '600',
  },
  date: {
    color: colors.grey3,
    fontSize: 12,
    marginBottom: global.style.defaultPadding,
  },
  footer: {
    padding: 2,
    alignSelf: 'flex-end',
  },
  footerContainer: {
    marginTop: global.style.defaultPadding,
    flexDirection: 'row',
    justifyContent: 'flex-start',
  },
  attachment: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  attachmentIcon: {
    tintColor: colors.link,
  },
  attachmentText: {
    color: colors.link,
    fontFamily: BOLD_FONT,
    marginLeft: 6,
    fontSize: 14,
  },
})
