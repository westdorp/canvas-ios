// @flow

import { combineReducers, Reducer } from 'redux'
import { courses } from '../modules/courses/courses-reducer'
import { favoriteCourses } from '../modules/courses/favorites/favorite-courses-reducer'
import { gradingPeriods } from '../modules/assignments/grading-periods-reducer'
import { assignmentGroups, assignments } from '../modules/assignments/assignments-reducer'
import logout from './logout-action'

const entities = combineReducers({
  courses,
  assignmentGroups,
  gradingPeriods,
  assignments,
})

const actualRootReducer: Reducer<AppState, Action> = combineReducers({
  favoriteCourses,
  entities,
})

export default function rootReducer (state: ?AppState, action: Action): AppState {
  if (action.type === logout.type) {
    state = undefined
  }
  return actualRootReducer(state, action)
}
