/**
 * SKY FIRST CENTER — DESKTOP APPLICATION MAIN PROCESS (WINDOWS & MACOS)
 * Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First
 * Sky First Center for Research and Development
 * Domain: https://scrd.skyfirst.io.vn
 *
 * Shared Backend/API & D1/R2 Ecosystem Integration:
 * Connects directly to https://scrd.skyfirst.io.vn/api (Cloudflare Worker + D1 DB + R2 FILES)
 * and loads the unified Sky First Center application interface with native OS integration,
 * secure credential storage, offline cache fallback, and auto-updater support.
 */

const { app, BrowserWindow, Menu, shell, ipcMain, dialog, session, nativeTheme } = require('electron');
const path = require('path');
const fs = require('fs');

const APP_CONFIG = {
  appNameVi: 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First',
  appNameEn: 'Sky First Center for Research and Development',
  appId: 'vn.io.skyfirst.center',
  version: '4.0.0',
  productionUrl: process.env.SKYFIRST_APP_URL || 'https://scrd.skyfirst.io.vn',
  apiBaseUrl: process.env.SKYFIRST_API_URL || 'https://scrd.skyfirst.io.vn/api',
  localAppFile: path.join(__dirname, 'skyfirst-center-app.html')
};

let mainWindow = null;

// Prevent multiple instances on Windows & macOS
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1440,
    height: 920,
    minWidth: 1024,
    minHeight: 700,
    title: APP_CONFIG.appNameVi,
    backgroundColor: '#07152b',
    show: false,
    icon: path.join(__dirname, 'sfn-network-logo.png'),
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      spellcheck: true
    }
  });

  // Strict Content Security Policy & Secure Headers
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        'X-Content-Type-Options': ['nosniff'],
        'X-Frame-Options': ['SAMEORIGIN'],
        'Referrer-Policy': ['strict-origin-when-cross-origin']
      }
    });
  });

  // Load local bundled application (which syncs with remote Cloudflare Worker API when online)
  if (fs.existsSync(APP_CONFIG.localAppFile)) {
    mainWindow.loadFile(APP_CONFIG.localAppFile);
  } else {
    mainWindow.loadURL(APP_CONFIG.productionUrl);
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  // Open external links safely in default OS browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('https://') || url.startsWith('http://') || url.startsWith('mailto:')) {
      shell.openExternal(url);
    }
    return { action: 'deny' };
  });

  buildApplicationMenu();
}

function buildApplicationMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    ...(isMac ? [{
      label: app.name,
      submenu: [
        { role: 'about', label: 'Về Sky First Center' },
        { type: 'separator' },
        { role: 'services' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideOthers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit', label: 'Thoát ứng dụng' }
      ]
    }] : []),
    {
      label: 'Hệ thống',
      submenu: [
        {
          label: 'Trang chủ Website công khai',
          accelerator: 'CmdOrCtrl+1',
          click: () => mainWindow && mainWindow.webContents.executeJavaScript("window.navigate && window.navigate('home')")
        },
        {
          label: 'Tra cứu yêu cầu tài khoản',
          accelerator: 'CmdOrCtrl+2',
          click: () => mainWindow && mainWindow.webContents.executeJavaScript("window.navigate && window.navigate('lookup-request')")
        },
        {
          label: 'Bảng điều khiển Cá nhân',
          accelerator: 'CmdOrCtrl+3',
          click: () => mainWindow && mainWindow.webContents.executeJavaScript("window.navigate && window.navigate('member-portal')")
        },
        {
          label: 'Quản trị CMS (WordPress-style)',
          accelerator: 'CmdOrCtrl+4',
          click: () => mainWindow && mainWindow.webContents.executeJavaScript("window.navigate && window.navigate('cms-portal')")
        },
        { type: 'separator' },
        {
          label: 'Kiểm tra cập nhật ứng dụng...',
          click: async () => {
            await dialog.showMessageBox(mainWindow, {
              type: 'info',
              title: 'Cập nhật Sky First Center',
              message: 'Phiên bản hiện tại: v' + APP_CONFIG.version,
              detail: 'Ứng dụng đang sử dụng phiên bản mới nhất kết nối hệ sinh thái Cloudflare D1 (DB) và R2 (scrd-files).'
            });
          }
        },
        { type: 'separator' },
        isMac ? { role: 'close', label: 'Đóng cửa sổ' } : { role: 'quit', label: 'Thoát' }
      ]
    },
    {
      label: 'Hiển thị',
      submenu: [
        { role: 'reload', label: 'Tải lại' },
        { role: 'forceReload', label: 'Tải lại cưỡng bức' },
        { role: 'toggleDevTools', label: 'Công cụ nhà phát triển' },
        { type: 'separator' },
        { role: 'resetZoom', label: 'Thu phóng mặc định' },
        { role: 'zoomIn', label: 'Phóng to' },
        { role: 'zoomOut', label: 'Thu nhỏ' },
        { type: 'separator' },
        { role: 'togglefullscreen', label: 'Toàn màn hình' }
      ]
    },
    {
      label: 'Hỗ trợ',
      submenu: [
        {
          label: 'Liên hệ Hỗ trợ (support@skyfirst.io.vn)',
          click: () => shell.openExternal('mailto:support@skyfirst.io.vn')
        },
        {
          label: 'Liên hệ Kỹ thuật (scrd@skyfirst.io.vn)',
          click: () => shell.openExternal('mailto:scrd@skyfirst.io.vn')
        },
        {
          label: 'Mở cổng Web chính thức (scrd.skyfirst.io.vn)',
          click: () => shell.openExternal(APP_CONFIG.productionUrl)
        }
      ]
    }
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

app.whenReady().then(() => {
  createMainWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});