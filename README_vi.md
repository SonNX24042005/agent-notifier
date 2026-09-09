# AI agent desktop notifier (anoti)

[English](README.md)

Hệ thống thông báo nổi đa màn hình (multi-monitor desktop notification overlay) kết hợp tự động chuyển đổi tiêu điểm cửa sổ (auto focus window) dành cho các công cụ AI coding agent: **Claude Code**, **Google Antigravity**, và **OpenAI Codex** trên cả **Linux** (X11 / GNOME) và **Windows** (10 / 11).

---

## Tính năng nổi bật

- **Hiển thị trên tất cả màn hình**: Tự động nhận diện toàn bộ màn hình đang kết nối (Xinerama/XRandR trên Linux, Win32 Monitor API trên Windows), hiển thị đồng thời banner nổi dark-slate trên từng màn hình kèm âm thanh cảnh báo hệ thống.
- **Hỗ trợ Windows**: Cửa sổ nổi Tkinter hiển thị trên các màn hình, giữ nguyên cho đến khi được xử lý và mang đúng identity cửa sổ nguồn. Windows toast chỉ được dùng khi không thể khởi tạo overlay.
- **Tự động chuyển workspace và focus cửa sổ theo identity đã xác minh**:
  - **Tự động chuyển đúng không gian làm việc (workspace)**: Nhận diện không gian làm việc chứa cửa sổ ứng dụng và tự động chuyển màn hình sang đúng workspace đó trước khi kích hoạt cửa sổ (Linux).
  - **Bỏ qua giới hạn foreground lock (Windows)**: Sử dụng kỹ thuật `AttachThreadInput` và `SetForegroundWindow` của Win32 API để đưa cửa sổ IDE/terminal lên đầu màn hình ngay lập tức mà không bị hiện tượng nhấp nháy thanh tác vụ.
  - **Tầng 1 (Session cache)**: Tra cứu ID cửa sổ đã lưu từ đầu phiên (`SessionStart`/`PreInvocation`) kèm kiểm tra tính hợp lệ và PID sở hữu cửa sổ để tránh dùng lại ID cũ. PID cửa sổ được lưu riêng với PID ngắn hạn của hook, nên nút đến cửa sổ, tự động đóng và `Alt+Q` vẫn hoạt động sau khi hook kết thúc trên X11.
  - **Tầng 2 (Cây tiến trình PID)**: Lần ngược cây PID cha (`/proc/{pid}/stat` trên Linux hoặc Win32 Toolhelp snapshot trên Windows) kết hợp tên thư mục dự án để tìm cửa sổ terminal/IDE tương ứng.
  - **Tầng 3 (Window ID trực tiếp)**: Xác thực ID cửa sổ được truyền trực tiếp qua tham số `--window-id` (phải là cửa sổ nhà phát triển hợp lệ).
  - **Tầng 4 (GNOME Terminal trên Wayland)**: Dùng adapter D-Bus khi quan hệ tiến trình chứng minh agent chạy trong GNOME Terminal.
  - **Tầng cuối an toàn**: Trả về không có mục tiêu nếu bằng chứng còn mơ hồ; không chọn cửa sổ developer ngẫu nhiên.
  - **Focus native Wayland**: Trên GNOME Shell, adapter chụp một token riêng cho cửa sổ đang focus ở đầu phiên. Token kết hợp namespace của phiên Shell và stable sequence của cửa sổ, nhờ đó hai cửa sổ Codex hoặc Antigravity trong cùng tiến trình vẫn được phân biệt.
- **Stack thông báo theo cửa sổ**: Mỗi cửa sổ chỉ giữ thông báo mới nhất, kể cả khi nhiều agent hoặc session cùng chạy trong cửa sổ đó. Các cửa sổ khác nhau được xếp theo thứ tự mới nhất trước. Khi thông báo trên cùng được xử lý, thông báo gần nhất còn chờ tự hiện lại.
- **Tự động đóng ngay khi cửa sổ nguồn được focus**: Engine kiểm tra đúng handle hoặc token của cửa sổ thay vì suy ra từ PID hay tên ứng dụng. Khi người dùng chuyển vào bất kỳ cửa sổ nào đang có thông báo chờ, mục tương ứng được xóa ngay; nếu đó là popup đang hiển thị thì popup đóng và stack chuyển sang mục tiếp theo.
- **Thông báo tồn tại đến khi xử lý**: Overlay không tự hết hạn khi `--timeout=0`, và item trong stack không bị loại theo tuổi. Đóng popup, focus đúng cửa sổ hoặc chuyển cửa sổ thành công mới giải quyết item.
- **Chống lặp theo cửa sổ**: Nội dung được băm cùng identity nguồn, vì vậy bản trùng từ một cửa sổ được chặn trong thời gian làm mát nhưng hai cửa sổ gửi cùng nội dung vẫn có thông báo riêng.
- **Chuyển tiếp đa kênh (webhooks)**: Gửi thông báo ngầm đến điện thoại hoặc kênh chat nhóm (Slack, Discord, Bark iOS, ntfy, Feishu, DingTalk) khi bạn rời khỏi bàn làm việc.
- **Tương tác nhanh và phím tắt**:
  - **Phím tắt toàn cục (`Alt + Q`)**: Đang làm việc ở bất kỳ đâu (lướt web, đọc tài liệu, soạn thảo), chỉ cần bấm `Alt + Q` (trên Linux) hoặc gọi lệnh `anoti focus` để chuyển ngay đến cửa sổ AI agent đang chờ phản hồi. Phím tắt, lệnh CLI và nút popup dùng cùng identity đã lưu trong queue.
  - **Tương tác trực tiếp trên popup**: Nhấn nút *"Đến cửa sổ (Alt+Q)"*, hoặc dùng phím tắt `Enter` / `Space` / `F` để chuyển vào ứng dụng, `Esc` / `Q` để đóng popup. Nút hiển thị *"Đang chuyển..."* khi yêu cầu focus chạy ở nền và tự bật lại nếu chưa tìm thấy cửa sổ đích.
- **Bộ công cụ CLI `anoti`**: Lệnh ngắn gọn, tiện lợi để focus cửa sổ, cập nhật, kiểm tra trạng thái, bắn thông báo thử nghiệm và gỡ cài đặt ở bất kỳ đâu trên hệ thống.

---

## Hỗ trợ các AI agent

1. **Claude Code** (tích hợp qua hook vòng đời trong `~/.claude/settings.json`: `SessionStart`, `PreToolUse: AskUserQuestion`, `Notification`, `Stop`).
2. **OpenAI Codex** (tích hợp qua các hook `SessionStart`, `UserPromptSubmit`, `PermissionRequest`, `Stop` trong `~/.codex/hooks.json`; cần phiên bản hỗ trợ các hook này, đã xác minh hợp đồng với 0.153.4).
3. **Google Antigravity** (hook vòng đời `desktop-notifier` trong `~/.gemini/config/hooks.json` và `~/.gemini/antigravity-cli/hooks.json` cho lệnh `agy`; installer/updater cấu hình cả hai trên Linux và Windows).

Khi nâng cấp, installer tự thay hook Codex cũ `anoti hook codex` bằng adapter hiện tại để tránh lỗi `Hook failed` với mã thoát `2`. Các hook không thuộc notifier được giữ lại.

Trên Windows, capture đã xác minh lưu token riêng trong property của cửa sổ để phân biệt hai cửa sổ Terminal dùng chung PID, kể cả khi tiêu đề đổi hoặc không chứa tên dự án. Token mất khi cửa sổ đóng; nếu Windows không cho ghi property, notifier vẫn dùng kiểm tra tiêu đề/PID thận trọng. Sau khi cập nhật, mở lại phiên `agy`; với Codex, gửi prompt mới từ cửa sổ nguồn để nâng cấp cache cũ. `anoti status` báo riêng trạng thái Antigravity và Antigravity CLI.

Hook Windows dùng PowerShell `-EncodedCommand` để truyền đường Python/adapter qua CMD mà không bị lỗi escape dấu ngoặc kép. Payload được chuyển qua stdin UTF-8; không cần đổi từ CMD sang PowerShell để dùng agent. Sau khi cập nhật cấu hình hook, mở lại phiên Codex/AGY để agent nạp lệnh mới.

Với agent chạy trong Windows Terminal/CMD, engine lấy HWND từ console của tiến trình `codex.exe`/`agy.exe`/`claude.exe` và owner của console. Vì vậy cửa sổ Terminal thứ hai vẫn được nhận diện khi Terminal dùng chung PID hoặc không nằm trong cây PID cha của CMD. Capture không lấy console PowerShell tạm của hook. Nếu backend không cung cấp owner hiển thị, engine quay về cache/PID và không đoán khi còn nhiều ứng viên.

Codex 0.153.4 còn gọi legacy `notify` cho tác vụ nền tạo tiêu đề, khiến lượt đầu có thêm thông báo không thuộc hội thoại đang mở. Notifier dùng `Stop` để loại nguồn thông báo phụ này. `UserPromptSubmit` bắt lại cửa sổ nguồn nếu capture đầu phiên bị hụt; hai cửa sổ cùng terminal được phân biệt bằng token riêng. Khi chưa có cửa sổ chính xác, notifier giữ thông báo và không tự đóng chỉ vì một cửa sổ khác cùng tiến trình được focus.

Thông báo đã tìm được cửa sổ sẽ thay thế bản cũ chưa tìm được cửa sổ của cùng phiên, tránh xuất hiện lại một bản không chuyển được đến nguồn sau khi xử lý bản mới.

Trên GNOME Wayland, extension 4 nhận diện app ID `org.gnome.Terminal` và hook Codex bắt cửa sổ đồng bộ ngay đầu phiên. Sau khi nâng cấp extension, đăng xuất/đăng nhập nếu installer báo runtime còn cũ, rồi mở lại các phiên Codex để thay danh tính ứng dụng cũ bằng token từng cửa sổ. Codex dùng mã thread + turn để loại sự kiện giao lại, kể cả sau khi thông báo đã đóng. Nhật ký chẩn đoán giới hạn 200 sự kiện nằm trong `notification_trace.json` ở thư mục runtime, chỉ chứa metadata định tuyến.

Trên X11, capture đã xác minh dùng mã riêng gắn với cửa sổ, nên terminal đổi tiêu đề hoặc nhiều cửa sổ dùng chung PID không làm mất nút đến cửa sổ/tự đóng. Các hook capture chờ hoàn tất trước khi trả về để giữ ancestry của tiến trình gọi. Sau cập nhật, mở lại agent để capture lại phiên cũ; Codex và Antigravity cũng capture lại qua hook đầu lượt.

Kiểm thử X11 thật: `NOTIFIER_TEST_X11=1 /usr/bin/python3 -m unittest discover -s tests -p 'test_x11_window_regressions.py' -v`. Test mở hai WezTerm và một GNOME Terminal tạm, chạy payload mô phỏng cho các adapter, đổi tiêu đề và kiểm tra focus/tự đóng/stack; tự dọn các cửa sổ thử, không gọi mô hình.

Kiểm thử tích hợp WezTerm thật: `NOTIFIER_TEST_WEZTERM=1 /usr/bin/python3 -m unittest discover -s tests -p 'test_codex_window_regressions.py' -v`. Bài test tạo hai cửa sổ WezTerm tạm cùng PID và tiêu đề, gửi payload hook mô phỏng để kiểm tra capture bị hụt, stack B → A và lượt kế tiếp ở A; tự dọn cửa sổ và runtime sau khi chạy. Không gọi mô hình Codex.

Kiểm thử tích hợp Wayland thật (tạo và focus hai cửa sổ tạm cùng một tiến trình): `NOTIFIER_TEST_WAYLAND=1 /usr/bin/python3 -m unittest discover -s tests -p 'test_codex_window_regressions.py' -v`. Kiểm thử này mặc định được bỏ qua; chỉ chạy trong phiên Linux Wayland có GTK3 và extension đang hoạt động.

Installer tắt `tui.notifications` của Codex để terminal như WezTerm không phát thêm banner bên cạnh overlay. Hãy mở lại Codex sau khi cài để cấu hình có hiệu lực. Giá trị trước đó được lưu bằng chú thích trong `config.toml` và được khôi phục khi gỡ cài đặt nếu bạn chưa sửa giá trị này. Thông báo hoàn tất dùng `Stop` với `session_id` và `turn_id`. Installer bỏ lệnh `notify` cũ của notifier; adapter bỏ qua payload legacy còn được gửi từ tiến trình Codex chưa khởi động lại. Cần mở lại Codex để nạp các hook mới.

---

## Cài đặt nhanh

### Trên Windows (PowerShell)

Mở **PowerShell** (hoặc Windows Terminal) và chạy lệnh sau:

```powershell
irm https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/install.ps1 | iex
```

### Trên Linux (Ubuntu / Debian / Fedora / Arch)

Mở **Terminal** và chạy lệnh sau:

```bash
curl -fsSL https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/install.sh | bash
```

Sau khi cài đặt xong, hãy tải lại cửa sổ VS Code / IDE của bạn:
> `Ctrl + Shift + P` -> `Developer: Reload Window`

---

## Hướng dẫn sử dụng bộ lệnh `anoti`

Sau khi cài đặt, bạn có thể gọi lệnh `anoti` từ bất kỳ thư mục nào trên máy (hỗ trợ cả PowerShell, CMD, Git Bash, và Linux bash/zsh):

```bash
# 1. Chuyển ngay đến cửa sổ AI agent đang chờ phản hồi
anoti focus
# hoặc dùng cờ ngắn:
anoti -f

# 2. Cập nhật hệ thống thông báo lên bản mới nhất
anoti update
# hoặc dùng cờ ngắn:
anoti -u

# 3. Chẩn đoán sức khỏe hệ thống và kiểm tra đồng bộ phiên bản
anoti doctor
# hoặc dùng alias:
anoti doc

# 4. Kiểm tra trạng thái tích hợp
anoti status
# hoặc:
anoti -s

# 5. Bắn thử thông báo kiểm tra lên tất cả màn hình
anoti test
# hoặc:
anoti -t

# 6. Xem hoặc tạo file cấu hình webhook (Slack, Discord, Bark, ntfy,...)
anoti config
# hoặc:
anoti -c

# 7. Bắn thông báo tùy chỉnh từ terminal hoặc shell script
anoti --title "Xong việc" --message "Tiến trình build đã hoàn tất sau 45 giây"

# 8. Gỡ cài đặt hệ thống thông báo và khôi phục file cấu hình sạch sẽ
anoti uninstall
```

---

## Cập nhật từ xa

### Trên Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/update.ps1 | iex
```

### Trên Linux

```bash
curl -fsSL https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/update.sh | bash
```

---

## Gỡ cài đặt từ xa

### Trên Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/uninstall.ps1 | iex
```

### Trên Linux

```bash
curl -fsSL https://raw.githubusercontent.com/SonNX24042005/agent-notifier/master/uninstall.sh | bash
```

---

## Cấu hình webhook (tùy chọn)

Để nhận thông báo trên điện thoại hoặc nhóm chat khi bạn không ngồi trước máy tính, tạo file `~/.config/ai-agent-notifier/config.json` (hoặc chạy lệnh `anoti config`):

```json
{
  "webhooks": {
    "slack": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
    "discord": "https://discord.com/api/webhooks/YOUR/WEBHOOK/URL",
    "bark": "https://api.day.app/YOUR_KEY",
    "ntfy": "https://ntfy.sh/your_topic",
    "feishu": "https://open.feishu.cn/open-apis/bot/v2/hook/YOUR_KEY",
    "dingtalk": "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN"
  }
}
```

---

## Cấu trúc thư mục dự án

Tài liệu dành cho người phát triển và coding agent: [Thiết kế kiến trúc](CONTRIBUTING.md) và [Quy chuẩn đóng góp](CONTRIBUTING.md).

```
ai-agent-desktop-notifier/
├── bin/
│   ├── anoti                     # Công cụ CLI quản lý đa nền tảng
│   ├── anoti.cmd                 # Wrapper cho Windows Command Prompt
│   ├── anoti.ps1                 # Wrapper cho PowerShell
│   └── multi-desktop-notify.py   # Engine popup đa màn hình, toast và focus cửa sổ
│   ├── architecture.md           # Thiết kế kiến trúc và hướng dẫn mở rộng
│   └── windows-guide.md          # Hướng dẫn chi tiết cho người dùng Windows
├── hooks/
│   ├── claude-notify.py          # Script xử lý hook vòng đời Claude Code (đa nền tảng)
│   ├── claude-notify.sh          # Script xử lý hook vòng đời Claude Code (Linux)
│   ├── codex-notify.py           # Script xử lý thông báo OpenAI Codex (đa nền tảng)
│   ├── antigravity-notify.py     # Script xử lý hook Google Antigravity (đa nền tảng)
│   └── antigravity-notify.sh     # Script xử lý hook Google Antigravity (Linux)
├── gnome-shell-extension/        # Adapter focus cửa sổ native Wayland trên GNOME Shell
├── install.ps1                   # Kịch bản cài đặt tự động trên Windows (PowerShell)
├── install.sh                    # Kịch bản cài đặt tự động trên Linux (Bash)
├── update.ps1                    # Kịch bản cập nhật trên Windows
├── update.sh                     # Kịch bản cập nhật trên Linux
├── uninstall.ps1                 # Kịch bản gỡ cài đặt trên Windows
├── uninstall.sh                  # Kịch bản gỡ cài đặt trên Linux
├── CONTRIBUTING.md               # Quy chuẩn đóng góp mã nguồn mở
├── README.md                     # Tài liệu hướng dẫn sử dụng tiếng Anh
├── README_vi.md                  # Tài liệu hướng dẫn sử dụng tiếng Việt
├── .gitignore
└── LICENSE
```

---

## Giấy phép

Dự án được phân phối theo giấy phép mã nguồn mở [MIT License](LICENSE).
