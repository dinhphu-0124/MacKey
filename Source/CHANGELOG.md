# Change Log

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
