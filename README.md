# LibreNMS 安裝腳本
## LibreNMS install script

---

## 翻譯為繁體中文版本
最初在 Ubuntu 18.04 LTS 上安裝 LibNMS 的批次腳本。  
目前已更新腳本能夠在 Ubuntu 24.04 LTS 上正常運行  
修復了錯誤並全面測試了腳本。確保運行驗證並修復資料庫表。  

---

## 使用方法
1. 安裝 wget (已安裝可跳過):
    ```sh
    sudo apt install wget -y
    ```
2. 下載腳本:
    ```sh
    sudo wget https://github.com/zz22558822/LibreNMS_Install/blob/master/LibreNMS_Install.sh
    ```
3. 運行腳本:
    ```sh
    sudo chmod +x LibreNMS_Install.sh && sudo bash ./LibreNMS_Install.sh
    ```

---

※ 此專案分支於  [straytripod](https://github.com/straytripod/LibreNMS-Install "straytripod Github")

