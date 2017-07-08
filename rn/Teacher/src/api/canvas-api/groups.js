// @flow
import { paginate, exhaust } from '../utils/pagination'
import httpClient from './httpClient'

export function getGroupsForCourse (courseID: string): Promise<ApiResponse<Array<Group>>> {
  const groups = paginate(`courses/${courseID}/groups`, {
    params: { include: ['users'] },
  })
  return exhaust(groups)
}

export function getGroupsForCategoryID (groupCategoryID: string): Promise<ApiResponse<Array<Group>>> {
  const groups = paginate(`group_categories/${groupCategoryID}/groups`, {
    params: { include: ['users'] },
  })
  return exhaust(groups)
}

export function getGroupByID (groupID: string): Promise<ApiResponse<Array<Group>>> {
  const url = `groups/${groupID}`
  return httpClient().get(url)
}
