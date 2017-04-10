/* eslint-disable comma-dangle */
/* global boardsMockInterceptor */
/* global BoardService */
/* global List */
/* global ListIssue */
/* global listObj */
/* global listObjDuplicate */

import Vue from 'vue';

require('~/lib/utils/url_utility');
require('~/boards/models/issue');
require('~/boards/models/label');
require('~/boards/models/list');
require('~/boards/models/user');
require('~/boards/services/board_service');
require('~/boards/stores/boards_store');
require('./mock_data');

describe('List model', () => {
  let list;

  beforeEach(() => {
    Vue.http.interceptors.push(boardsMockInterceptor);
    gl.boardService = new BoardService('/test/issue-boards/board', '', '1');
    gl.issueBoards.BoardsStore.create();

    list = new List(listObj);
  });

  afterEach(() => {
    Vue.http.interceptors = _.without(Vue.http.interceptors, boardsMockInterceptor);
  });

  it('gets issues when created', (done) => {
    setTimeout(() => {
      expect(list.issues.length).toBe(1);
      done();
    }, 0);
  });

  it('saves list and returns ID', (done) => {
    list = new List({
      title: 'test',
      label: {
        id: _.random(10000),
        title: 'test',
        color: 'red'
      }
    });
    list.save();

    setTimeout(() => {
      expect(list.id).toBe(listObj.id);
      expect(list.type).toBe('label');
      expect(list.position).toBe(0);
      done();
    }, 0);
  });

  it('destroys the list', (done) => {
    gl.issueBoards.BoardsStore.addList(listObj);
    list = gl.issueBoards.BoardsStore.findList('id', listObj.id);
    expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(1);
    list.destroy();

    setTimeout(() => {
      expect(gl.issueBoards.BoardsStore.state.lists.length).toBe(0);
      done();
    }, 0);
  });

  it('gets issue from list', (done) => {
    setTimeout(() => {
      const issue = list.findIssue(1);
      expect(issue).toBeDefined();
      done();
    }, 0);
  });

  it('removes issue', (done) => {
    setTimeout(() => {
      const issue = list.findIssue(1);
      expect(list.issues.length).toBe(1);
      list.removeIssue(issue);
      expect(list.issues.length).toBe(0);
      done();
    }, 0);
  });

  it('sends service request to update issue label', () => {
    const listDup = new List(listObjDuplicate);
    const issue = new ListIssue({
      title: 'Testing',
      iid: _.random(10000),
      confidential: false,
      labels: [list.label, listDup.label]
    });

    list.issues.push(issue);
    listDup.issues.push(issue);

    spyOn(gl.boardService, 'moveIssue').and.callThrough();

    listDup.updateIssueLabel(issue, list);

    expect(gl.boardService.moveIssue)
      .toHaveBeenCalledWith(issue.id, list.id, listDup.id, undefined, undefined);
  });
});
