# GrindTracker 🎒

[![WoW Version](https://img.shields.io/badge/WoW-Retail%20%7C%20Classic-blue.svg)](https://worldofwarcraft.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**GrindTracker** is a World of Warcraft addon that tracks farmed items and displays their total count (including bank inventory) in your DataBroker bar (Titan Panel, ElvUI, etc.) or on your Minimap. 

## 🚀 Features

- **Intuitive Inventory Hook:** Hold `ALT + Right-Click` on any item in your bags to instantly add it to your tracker or remove it.
- **Visual Management:** Clean Ace3-powered settings menu to manage tracked items via icon clicks.
- **Universal Display:** Built on `LibDataBroker-1.1` and `LibDBIcon-1.0`. Plugs into any LDB bar or provides a standalone Minimap button.
- **Performance Optimized:** Only executes tracking logic on `BAG_UPDATE` events.
- **Multi-Language Support:** Fully localized in English, German, French, Spanish, Russian, and Simplified Chinese.

## 🛠️ Installation

1. Download the latest release from the [Releases](../../releases) page or via CurseForge.
2. Extract the `GrindTracker` folder into your `_retail_\Interface\AddOns\` directory.
3. Make sure the `Libs` folder is included inside the `GrindTracker` directory.
4. Restart World of Warcraft or type `/reload` in the chat.

## 🎮 Usage

- **Add/Remove Items:** Open your bags, hold **ALT** and **Right-Click** the item you want to track.
- **Open Settings:** Right-click the GrindTracker display on your DataBroker bar or the Minimap button.
- **Remove via Menu:** Open the settings and click on the icon of a tracked item to stop tracking it.

## 📦 Dependencies
This addon relies on the following embedded libraries:
- [Ace3](https://www.curseforge.com/wow/addons/ace3) (AceAddon, AceConsole, AceEvent, AceDB, AceGUI, AceConfig, AceLocale)
- [LibDataBroker-1.1](https://github.com/tekkub/libdatabroker-1-1)
- [LibDBIcon-1.0](https://www.curseforge.com/wow/addons/libdbicon-1-0)

## ✍️ Author & Copyright

Created and maintained by **BloodDragon2580**  
Website: [Gaming-Nexus](https://gaming-nexus.de)