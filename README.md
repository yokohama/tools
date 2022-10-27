# tools

## github

### create_label.sh
1. labels.txtで、作成するラベルを管理します。
2. 以下のコマンドでラベルを生成できます。
```
./create_label labels.txt
```

### create_issue.sh
1. create_issue.config.jsonファイルでissue作成の対象のコメントパターンを設定します。
```
cp create_issue.config.json.sample create_issue.config.json
```
2. 以下のコマンドで、ソースコード中の対象コメントをissue化します。
```
create_issue.sh create_issue.config.json
```
