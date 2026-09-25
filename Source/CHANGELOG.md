# Change Log

##### Version 1.0.4: (2026)
- **Thiết kế lại bố cục & tối ưu thanh chân trang cửa sổ Gõ tắt (Macro):**
  - Loại bỏ tuỳ chọn trùng lặp "Tự động viết hoa theo phím tắt" khỏi cửa sổ Thiết lập gõ tắt (chỉ quản lý tập trung tại tab Gõ tắt trong Bảng điều khiển).
  - Di chuyển huy hiệu số lượng `📖 75 từ tắt` vào giữa thanh công cụ chân trang, đặt liền sau nút "Xuất File...".
  - Tách nút Thùng rác 🗑️ sang góc dưới bên phải ngoài cùng với màu đỏ cảnh báo (`systemRedColor`).
- **Tooltip hướng dẫn trực quan cho tính năng "Tự động viết hoa theo phím tắt":**
  - Hiển thị đầy đủ ví dụ minh hoạ khi di chuột qua nút gạt tại Bảng điều khiển (ko=không ➔ ko=không, Ko=Không, KO=KHÔNG).
- **Làm mới toàn diện tab "Thông tin" trong Bảng điều khiển:**
  - Cập nhật danh sách tính năng mới nhất: Viết hoa thông minh, Gợi ý nổi tức thì, Quản lý Excel/CSV, Công cụ chuyển mã, Đa dạng bảng mã.
  - Áp dụng kỹ thuật thụt lề treo (Hanging Indent 22pt) với dấu chấm tròn xanh ngọc (Teal) chuẩn giao diện Apple, giúp dòng 2 và dòng 3 thẳng hàng tuyệt đối với chữ cái đầu dòng 1.
- **Tối ưu hóa Engine gõ phím & Viết hoa sau dấu câu:**
  - Sửa triệt để hiện tượng nuốt phím cách (Space) và đảm bảo tự động viết hoa chữ đầu câu sau các dấu kết thúc câu (`.`, `?`, `!`) và phím Enter hoạt động trơn tru.

##### Version 1.0.3: (2026)
- **Gợi ý từ gõ tắt nổi (Inline Macro Suggestion Tooltip/Popover):**
  - Tự động hiển thị bong bóng popover bo góc mềm mại ngay trên con trỏ soạn thảo văn bản khi đang gõ từ tắt (ví dụ: `cty`, `sn`, `stkbidv`, `hthong`...).
  - Nhấn phím **Space**: Tự động chuyển từ gõ tắt thành từ hoàn chỉnh và ẩn bong bóng gợi ý tức thì.
  - Hỗ trợ phím **Escape (Esc)** hoặc click nút **✕** trên bong bóng: Bỏ qua gợi ý và huỷ chuyển đổi gõ tắt cho từ đó (nhấn Space sau đó chỉ thêm khoảng trắng bình thường).
- **Quy tắc viết hoa thông minh theo ngữ cảnh câu:**
  - **Đầu câu:** Tự động viết hoa chữ cái đầu tiên của từ hoàn chỉnh khi từ gõ tắt đứng ở đầu câu, đầu tin nhắn hoặc đứng sau các dấu kết thúc câu (`.`, `!`, `?` kèm Space/Enter). Ví dụ: `cty không ổn lắm` ➔ `Công ty không ổn lắm`, `tôi khỏe! bt` ➔ `tôi khỏe! Bình thường`.
  - **Giữa câu:** Tự động chuyển chữ cái đầu tiên thành chữ thường khi từ gõ tắt đứng ở giữa câu hoặc sau dấu phẩy (kể cả khi từ tắt được lưu trong từ điển bằng chữ hoa). Ví dụ: `hp` lưu là `Hạnh phúc`, khi gõ `Hôm nay, tôi hp` ➔ `Hôm nay, tôi hạnh phúc`.
  - **Tôn trọng phím Shift:** Khi người dùng chủ động gõ phím viết hoa bằng Shift (ví dụ `Hp` hoặc `HP`), ứng dụng giữ nguyên cách viết hoa theo đúng ý định.
- **Tuỳ chọn trong Bảng điều khiển:**
  - Bổ sung công tắc `[✔] Hiển thị gợi ý khi gõ từ tắt` trong tab "Gõ tắt", cho phép bật/tắt tính năng gợi ý linh hoạt theo sở thích cá nhân.

##### Version 1.0.2: (2026)
- **Tùy biến phím chuyển chế độ (Shortcut Key):**
  - Cải tiến ô nhập phím chuyển chế độ nhận diện phím vật lý độc lập với bộ gõ tiếng Việt, cho phép chọn bất kỳ phím ký tự/số/phím Space nào kết hợp cùng các phím bổ trợ (`⌥`, `⌃`, `⌘`, `⇧`).
  - Hỗ trợ phím Delete/Backspace để xoá ô ký tự, cho phép sử dụng chỉ các phím bổ trợ (như `⌃ Control + ⇧ Shift` quen thuộc).
  - Hiển thị badge huy hiệu phím tắt bo góc hiện đại theo phong cách macOS.
- **Chức năng "Khôi phục mặc định" an toàn:**
  - Hiển thị hộp thoại xác nhận chuyên nghiệp, thống kê chính xác số lượng từ tắt sẽ bị xoá.
  - Khôi phục toàn bộ cài đặt gốc của hệ thống và xoá sạch dữ liệu gõ tắt sau khi người dùng xác nhận.
- **Tối ưu Cửa sổ Thiết lập gõ tắt (MacroWindow):**
  - Thêm icon Thùng rác ở chân trang với tooltip và hộp thoại xác nhận xoá toàn bộ gõ tắt tiện lợi.
  - Thêm nút "Thêm mới" xuất hiện linh hoạt ngay trên đầu nút "Xoá", đồng bộ kích thước chuẩn (80x32) và hỗ trợ phím Return chuyển tiêu điểm mượt mà.
  - Tinh gọn chiều rộng nút "Nhập từ Excel...", cải thiện bố cục thanh chân trang co giãn responsive.
  - Khắc phục triệt để hiện tượng trùng lặp/lồng ghép icon cảnh báo hệ thống trong các thông báo (alert).
- **Màn hình Giới thiệu & Cập nhật:**
  - Tinh giản giao diện Giới thiệu chỉ còn 2 liên kết chính: GitHub và Phiên bản mới.
  - Nâng cấp tính năng "Kiểm tra bản mới..." đối chiếu tự động với GitHub Releases API và hiển thị hộp thoại xác nhận tải về trực quan.
- **Hoàn thiện tài liệu:**
  - Cập nhật toàn diện file `README.md` với hình ảnh minh họa chi tiết từng bước cài đặt, vượt Gatekeeper, cấp quyền Trợ năng và hướng dẫn sử dụng.

##### Version 1.0.1: (2026)
- Tinh chỉnh tính năng tự động viết hoa chữ cái đầu câu: chỉ tự động viết hoa sau các dấu kết thúc câu (. ? !), không ép viết hoa chữ cái đầu khi mở ô nhập mới, chuyển ứng dụng hoặc nhấn Enter xuống dòng.
- Giữ chữ thường mặc định khi bắt đầu gõ tin nhắn mới; viết hoa chữ đầu bằng phím Shift như thông thường.

##### Version 1.0.0: (2026)
- Bản đầu tiên của MacKey, build lại và tối ưu riêng cho macOS (không còn hỗ trợ Windows/Linux).
- Sửa lỗi treo cứng ứng dụng ngay khi khởi động.
- Sửa lỗi tiến trình nền MacKeyHelper bị hệ thống chặn, không tự khởi động cùng máy được.
- Sửa lỗi gõ sai dấu ảnh hưởng đến mọi bảng mã (lỗi duyệt sai kiểu dữ liệu bảng nội bộ trong engine).
- Sửa hàng loạt nút/công tắc trong Cài đặt bị kết nối sai nên bấm không có phản hồi (phím chuyển chế độ, khôi phục mặc định, mở bảng gõ tắt, đổi kiểu gõ/bảng mã, chế độ gõ Việt/Anh...).
- Tối ưu tính năng tự động viết hoa chữ cái đầu câu: chỉ kích hoạt sau các dấu kết thúc câu (. ? !), không tự ý viết hoa khi mở ô nhập mới hoặc chuyển ứng dụng.
- Thêm tính năng nhập nhanh danh sách gõ tắt từ tệp Excel (.xlsx) hoặc tệp CSV.
- Thêm tính năng xuất toàn bộ danh sách gõ tắt ra tệp Excel (.xlsx) hoặc tệp CSV với hộp thoại cảnh báo lựa chọn trực quan.
- Thêm tính năng nhấn phím Return (Enter) để chuyển nhanh tiêu điểm giữa 2 ô nhập liệu gõ tắt và tự động thực hiện Thêm/Cập nhật.
- Tinh chỉnh và thiết kế lại bố cục thiết lập gõ tắt cân đối (căn thẳng hàng lề trái nút Nhập/Xuất, tự động ẩn/hiển thị và thay đổi vị trí các nút "Thêm", "Cập nhật", "Xóa" thông minh).
- Bỏ các tính năng ghi nhớ/tạm tắt theo từng ứng dụng, sửa lỗi gợi ý trình duyệt, gửi từng phím — không cần thiết.
- Loại bỏ toàn bộ mã nguồn Windows và Linux, chỉ giữ lại engine và app macOS.

Xem chi tiết đầy đủ tại `README.md`.
