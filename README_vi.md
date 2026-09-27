# AI agent desktop notifier (anoti)

[English](README.md)

Hệ thống thông báo nổi đa màn hình với tính năng 1 chạm chuyển nhanh đến cửa sổ đang chạy dành cho các công cụ lập trình AI (**Claude Code**, **Google Antigravity**, và **OpenAI Codex**) trên cả **Linux** (X11 / GNOME) và **Windows** (10 / 11).

Giúp bạn không bỏ lỡ những lúc AI agent cần hỏi ý kiến, xin quyền thực thi hoặc khi agent đã hoàn thành tác vụ trong khi bạn đang làm việc ở cửa sổ khác.

---

## Tính năng nổi bật

- **Hiển thị trên tất cả màn hình**: Tự động phát hiện toàn bộ màn hình đang kết nối và hiển thị banner thông báo nổi kèm âm thanh cảnh báo, giúp bạn luôn nhìn thấy thông báo ở bất kỳ màn hình nào.
- **Chuyển nhanh đến cửa sổ (`Alt + Q`)**: Bấm nút *"Đến cửa sổ"* trên thông báo hoặc nhấn `Alt + Q` (hoặc chạy lệnh `anoti focus`) để chuyển ngay về cửa sổ terminal hoặc IDE mà AI agent đang chờ phản hồi.
- **Tự động đóng khi vào cửa sổ**: Ngay khi bạn mở hoặc chuyển đến cửa sổ của agent, banner thông báo sẽ tự động đóng lại.
- **Hàng đợi thông báo thông minh**: Tự sắp xếp và lưu trữ thông báo khi có nhiều agent cùng hoạt động. Xử lý xong một thông báo thì thông báo tiếp theo sẽ tự động hiển thị.
- **Chuyển tiếp đến điện thoại và ứng dụng chat**: Hỗ trợ gửi thông báo qua webhook (Slack, Discord, Bark, ntfy, Lark/Feishu, DingTalk) khi bạn rời bàn làm việc.
- **Hỗ trợ đa nền tảng**: Hoạt động mượt mà trên cả Linux (Ubuntu, Debian, Fedora, Arch) và Windows (10, 11).

---

## Các AI agent được hỗ trợ

- **Claude Code**
- **Google Antigravity** (`agy`)
- **OpenAI Codex**

Cấu hình hook tích hợp được tự động cài đặt trong quá trình cài đặt ứng dụng, hoặc bạn có thể làm mới bất kỳ lúc nào bằng lệnh `anoti setup-hooks`.

---

## Hướng dẫn cài đặt nhanh

### Trên Windows

- **Cách 1: Dùng bộ cài đặt giao diện `.exe` (khuyến nghị)**:
  Tải và chạy tệp `anoti-setup.exe` từ trang [GitHub Releases](https://github.com/SonNX24042005/agent-notifier/releases). Bộ cài đặt sẽ tự động thiết lập chương trình và tích hợp các hook cho agent.

- **Cách 2: Cài đặt bằng PowerShell**:
  Mở PowerShell và chạy lệnh sau:
  ```powershell
  irm https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/scripts/install.ps1 | iex
  ```

### Trên Linux (Ubuntu / Debian / Fedora / Arch)

- **Cách 1: Dùng gói cài đặt `.deb` cho Ubuntu / Debian (khuyến nghị)**:
  Tải gói `.deb` mới nhất từ trang [GitHub Releases](https://github.com/SonNX24042005/agent-notifier/releases) và cài đặt:
  ```bash
  sudo apt install ./ai-agent-desktop-notifier_1.3.1_all.deb
  anoti setup-hooks
  ```

- **Cách 2: Cài đặt bằng một dòng lệnh terminal**:
  Mở terminal và chạy lệnh:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/scripts/install.sh | bash
  ```

Sau khi cài đặt xong, hãy tải lại cửa sổ trình soạn thảo (ví dụ trong VS Code: nhấn `Ctrl + Shift + P` và chọn `Developer: Reload Window`).

---

## Lệnh tiện ích `anoti`

Sau khi cài đặt, bạn có thể gọi lệnh `anoti` từ bất kỳ cửa sổ dòng lệnh nào:

```bash
# Chuyển ngay đến cửa sổ agent đang chờ phản hồi
anoti focus

# Cài đặt hoặc làm mới hook cho các agent
anoti setup-hooks

# Bắn thông báo thử nghiệm trên các màn hình
anoti test

# Kiểm tra trạng thái tích hợp của các agent
anoti status

# Chẩn đoán sức khỏe hệ thống và kiểm tra phụ thuộc
anoti doctor

# Mở cấu hình webhook
anoti config

# Cập nhật phiên bản mới nhất
anoti update

# Gỡ cài đặt hoàn toàn khỏi hệ thống
anoti uninstall
```

### Thao tác nhanh trên banner thông báo

- `Enter` / `Space` / `F`: Chuyển ngay đến cửa sổ ứng dụng.
- `Esc` / `Q`: Đóng thông báo hiện tại.
- Phím tắt toàn cục: Nhấn `Alt + Q` (trên Linux) để chuyển về cửa sổ agent từ bất cứ đâu.

---

## Cấu hình webhook (tùy chọn)

Để nhận thông báo trên điện thoại hoặc các kênh chat nhóm khi không ngồi tại máy tính, hãy chạy lệnh `anoti config` hoặc chỉnh sửa tệp `~/.config/ai-agent-notifier/config.json`:

```json
{
  "webhooks": {
    "slack": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
    "discord": "https://discord.com/api/webhooks/YOUR/WEBHOOK/URL",
    "bark": "https://api.day.app/YOUR_KEY",
    "ntfy": "https://ntfy.sh/your_topic"
  }
}
```

---

## Giấy phép

Phát hành dưới giấy phép [MIT License](LICENSE).
