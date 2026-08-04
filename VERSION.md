# EastApp Development Version

Version name: `east_app_staffreward_v6`

Build label: `east_app_staffreward_v6_1_cardtheme_fix`

Flutter package name: `east_app`

Flutter app class: `TheEastApp`

Date locked: 2026-06-09

## Baseline decision

This version is a frontend-only Flutter prototype using hardcoded sample data.

The backend is not implemented in this project. Placeholder API methods, endpoint names, request JSON, and response JSON are documented so the future Java Spring Boot backend can be connected later.

## Included changes

- Bottom navigation is now: Home, Task, Rewards, Stock, Ranking, Knowledge.
- Stock tab is manager-only.
- Stock tab supports supplier visibility, stock balance display, stock status, and stock verification UI.
- Sample suppliers and items included:
  - Supreme Range: 美人鱼, 虾酱
  - A-Z: 冷杯, 热杯
  - GTI Kampar: 羊肉, 鸡肉
  - Grand Meltique: 炸莲藕, 蛋挞饼
- Manager SOP creation includes category dropdown:
  - Cleanliness, Hygiene, Quality, Safety, Stock, Inventory
- Manager SOP creation includes level dropdown:
  - Level 1, Level 2, Level 3, Level 4

## Rollback note

Use this zip as the rollback baseline before adding real backend calls, authentication, real camera upload, or real database integration.


## v6.1 compile fix

- Updated `ThemeData.cardTheme` from `CardTheme` to `CardThemeData` for newer Flutter versions where `cardTheme` expects `CardThemeData?`.
