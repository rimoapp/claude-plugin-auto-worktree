# loop-engineering — Claude Code Plugin

**任意のリポジトリで発火させると、そのリポジトリに「自走するループ」一式を構築する** Claude Code プラグインです。

設計の元ネタは Addy Osmani **「Loop Engineering」**（2026-06-07 / [addyosmani.com/blog/loop-engineering](https://addyosmani.com/blog/loop-engineering/)、O'Reilly Radar 転載）。Peter Steinberger の「エージェントにプロンプトするな、エージェントにプロンプトする**ループ**を設計しろ」を、Claude Code の実プリミティブ（Skills / Subagents / worktree / スケジューラ）に落とした最も実用的な一次記事です。

## 記事のアーキテクチャ → このプラグインの対応

| Osmaniの「5つの部品 + 記憶」 | このプラグインが生成するもの |
|---|---|
| 1. Automations（心臓・スケジュール実行） | `.github/workflows/loop-tick.yml`（cron + 手動発火）/ `tick-local.sh`（cron用）/ Routines・`/loop` の案内 |
| 2. Worktrees（並列の隔離） | `loop-builder` エージェントの `isolation: worktree` + `loop/<id>-<slug>` ブランチ運用 |
| 3. Skills（プロジェクト知識の外部化） | リポジトリ側 `.claude/skills/loop-tick` `loop-discover`（tickのアルゴリズム自体をスキル化） |
| 4. Plugins / Connectors（実ツール接続） | `gh` CLI 経由の Issue 読取・PR 作成（既存MCPがあればそれも尊重） |
| 5. Sub-agents（作る者と検証する者の分離） | `loop-builder`（メーカー）と `loop-verifier`（「壊れている前提」で審査、編集禁止） |
| 6. 記憶（ディスク上の状態） | `.loop/STATE.md`（背骨）+ `.loop/journal/`（実行ログ）— *モデルは忘れるが、リポジトリは忘れない* |

tick 1回のフロー: **Discover →（判断で）Select 1件 → Build（隔離ブランチ・最小diff）→ Verify（独立検証・`verify.sh` 再実行）→ Persist（PR作成・STATE/journal更新）→ Stop**。マージは絶対にしない（human gate）。

## インストール

いずれか1つ。

```bash
# A. rimo-tools マーケットプレイス経由（推奨・チーム配布向け）
/plugin marketplace add rimo/claude-plugins
/plugin install loop-engineering@rimo-tools

# B. セッション限定で試す（このリポジトリ内から）
claude --plugin-dir ./plugins/loop-engineering
```

検証: `claude plugin validate ./plugins/loop-engineering`

## 使い方

```
cd your-repo && claude
/loop-engineering:init      # ← これが「発火」。以下が起きる:
```

1. スタック検出（pnpm/go/cargo/py…、lint/typecheck/test の実在コマンドから `verify.sh` を合成）
2. 判断が要る点だけ質問（ループの恒常ゴール / スケジューラ / 頻度 / 発見ソース）
3. 下記一式を生成し、`discover.sh` を1回実行して **実在するタスクで Backlog を初期投入**
4. 次の手順（secret 設定、初回は対話で `/loop-tick` を監督実行、など）を提示

```
your-repo/
├── .loop/
│   ├── LOOP.md            # ループの憲法（ゴール/スコープ/予算/human gates）人間が編集
│   ├── STATE.md           # 記憶の背骨: Backlog / In Progress / Awaiting Review / Done / Triage Inbox
│   ├── journal/           # tick毎の追記ログ
│   └── bin/
│       ├── verify.sh      # 唯一のゲート（builderもverifierもこれを実行）
│       ├── discover.sh    # 決定的なシグナル収集（CI/issue/TODO/commits）
│       └── tick-local.sh  # ローカル/cron用ヘッドレス実行（claude -p "/loop-tick"）
├── .claude/
│   ├── skills/loop-tick/      # 1イテレーションのアルゴリズム（スケジューラから /loop-tick で発火）
│   ├── skills/loop-discover/  # 発見+トリアージのみの軽量版
│   └── agents/loop-builder.md / loop-verifier.md
└── .github/workflows/loop-tick.yml   # スケジューラ（GitHub Actions選択時）
```

生成後のリポジトリは**プラグイン非依存で自走**します（CIには何も追加インストール不要。`ANTHROPIC_API_KEY` を repo secret に設定するだけ）。

日常運用:

- `/loop-tick` — 手動で1周回す（導入直後は必ず1回、目視で監督してから定期実行を有効化）
- `/loop-discover` — Backlog だけ更新（安い・高頻度向け）
- `/loop-engineering:status` — 朝のブリーフィング（Triage Inbox / PR / 心拍の生存確認）
- Issue に `loop` ラベルを付ける = 人間からループへの投入口

## 安全設計（記事の警告をそのまま実装）

- **1 tick = 1 item**、修正サイクル上限3回 → 超えたら Triage Inbox へ退避（無限ループ・トークン溶かし防止）
- **human gates**: merge / default branch への push / force-push / deploy / 依存追加 は構造的に禁止
- **maker ≠ checker**: 検証者は書込ツール自体を剥奪（`disallowedTools`）。「done は主張であって証明ではない」
- 予算・スコープはすべて `.loop/LOOP.md` に集約 — 広げるのは数週間クリーンに回ってから

## カスタマイズ

`skills/init/templates/` を編集すれば、自社流のループ（例: Slack通知の追加、Linear連携、Rimoのタスク実行APIへの接続）を全リポジトリに一貫して配布できます。テンプレートの `{{PLACEHOLDER}}` は init 実行時に Claude が実リポジトリに合わせて埋めます。

## 参考

- Addy Osmani, ["Loop Engineering"](https://addyosmani.com/blog/loop-engineering/)（本プラグインの設計原典）
- [Claude Code Plugins reference](https://code.claude.com/docs/en/plugins-reference) / [GitHub Actions](https://code.claude.com/docs/en/github-actions)
