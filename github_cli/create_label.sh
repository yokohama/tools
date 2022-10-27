#!/bin/bash
#
# base/labels.txtの中身に記載されているラベルをリポジトリに作成します。
# 既に同じ名前のラベルが存在する場合は、作成をスキップします。
#
# (実行)
# .gitフォルダの設定を必要とするので、ラベルを作成したいリポジトリのディレクトリから実行してください。 
label_file=$1
if [ "${label_file}" = "" ]; then
  echo "ERROR: label file required."
  echo "ex) create_label.sh label.txt"
  exit 1
fi

set -eu

lines=(`cat ${label_file}`)

for line in ${lines[@]}; do
  title=`echo ${line} | cut -d ',' -f 1`
  color=`echo ${line} | cut -d ',' -f 2`
  desc=`echo ${line}  | cut -d ',' -f 3`

  gh label create "${title}" --description "${desc}" --color "${color}"
done
