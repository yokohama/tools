#!/bin/bash

COMMENT_TEMP_FILE=/tmp/comment.temp.txt
CONFIG_FILE=$HOME/create_issue.config.json

# 対象外にしたいファイルやディレクトリ名をセット
GREP_EXCLUDE_ARRAY=(
  "${BASH_SOURCE[0]}"
  "${COMMENT_TEMP_FILE}" 
  "${CONFIG_FILE}"
)

function json_convert_error() {
  echo "ERROR: incomplete json format. ${1}"
  echo ""

  exit 1
}

function create_issue_error() {
  echo "ERROR: create issue. ${1}"
  echo ""

  exit 1
}

function sed_error() {
  echo "ERROR: ファイルの置換に失敗したがIssueは作成されています。"
  echo "該当ファイル: ${1}"
  echo "該当Issue:    ${2}"
  echo ""

  exit 1
}

function create_comment_temp_file() {
  touch ${COMMENT_TEMP_FILE}

  local grep_cmd='grep -rn "ISSUE:"'
  for exclude in ${GREP_EXCLUDE_ARRAY[@]}; do
    grep_cmd="${grep_cmd} --exclude ${exclude}"
  done
  print_cmd_text=${grep_cmd}
  grep_cmd="${grep_cmd} ./* 1> ${COMMENT_TEMP_FILE}"

  echo "## Create comment temp file. [${COMMENT_TEMP_FILE}"
  eval ${print_cmd_text}
  echo ""

  echo `eval ${grep_cmd}`
  return 0
}

function get_line_suffix() {
  local line=$1

  echo "${line}" | awk -F ":" '{print $1}' | awk -F "." '{print $NF}'
  return 0
}

# ${COMMENT_TEMP_FILE}から、${CONFIG_FILE}にprefixの定義が無い行を削除
function exclude_undefined_suffix() {
  echo "## Exclude undefined suffixes."
  set -eu

  IFS=$'\n'
  for line in `cat ${COMMENT_TEMP_FILE}`; do
    local i
    local is_defined=false

    suffixes=(`cat ${CONFIG_FILE} | jq -r '.comments[].suffix'`)
    for i in ${suffixes[@]}; do
      if [[ ${i} = `get_line_suffix "${line}"` ]]; then
        is_defined=true
      fi
    done

    if ! "${is_defined}"; then
      echo `grep -nF "${line}" ${COMMENT_TEMP_FILE}`

      delete_line_number=`grep -nF "${line}" ${COMMENT_TEMP_FILE} | awk -F ":" '{print $1}'`
      sed -i "${delete_line_number}s/^.*$//" ${COMMENT_TEMP_FILE}
    fi
  done

  echo ""
  return 0
}

#
# gitHub issueの作成
# 注）echoを使いapiのresをリターンしてるので、表示用のechoはここでは使えません。
#
function create_github_issue() {
  local line=$1

  local title=`echo "${line}" | sed 's/^.*ISSUE://' | jq '.title'` || json_convert_error "${line}"
  local label=`echo "${line}" | sed 's/^.*ISSUE://' | jq '.label'` || json_convert_error "${line}"

  if [ "${label}" != "null" ]; then
    label=`echo "${label}" | sed -z 's/\n\|\[\|\]\| //g'`
    cmd="gh issue create --title ${title} --body 'Created by CLI' --label ${label}"
  else
    cmd="gh issue create --title ${title} --body 'Created by CLI'" 
  fi

  (echo `eval $cmd | grep https://github.com`) || create_issue_error "${line}"

  return 0
}

function override_comment() {
  echo "### Override comment by issue URL."

  local line=$1
  local begin=$2
  local end=$3
  local res=$4

  local override_comment_text="${begin} AT_SEE: ${res}"

  if [ "${end}" != "null" ]; then
    override_comment_text="${override_comment_text} ${end}"
  fi

  echo " => ${override_comment_text}"

  local file_path=`echo "${line}"   | awk -F ":" '{print $1}'`
  local line_number=`echo "${line}" | awk -F ":" '{print $2}'`

  echo `sed -i "${line_number}s,^.*$,${override_comment_text}," ${file_path} || sed_error "${line}" "${res}"`
  return 0
}

function main() {
  set -eu

  create_comment_temp_file
  exclude_undefined_suffix

  local line
  for line in `cat ${COMMENT_TEMP_FILE}`; do
    local line_suffix=`get_line_suffix "${line}"`

    local begin=`cat ${CONFIG_FILE} | jq -r '.comments[] | select(.suffix == "'${line_suffix}'").begin'` || json_convert_error "${line}"
    local end=`cat ${CONFIG_FILE}   | jq -r '.comments[] | select(.suffix == "'${line_suffix}'").end'`   || json_convert_error "${line}"

    if [ "${begin}" = "null" ]; then
      create_issue_error "${line}"
    fi

    local issue="${line}"

    if [ "${end}" != "null" ]; then
      issue=`echo "${line}" | sed "s/${end}//"`
    fi

    echo "### Create github issue."
    res=`create_github_issue "${issue}"`
    echo " => ${res}"

    override_comment "${line}" "${begin}" "${end}" "${res}"
  done

  return 0
}

main
