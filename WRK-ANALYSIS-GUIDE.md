# Hướng dẫn Phân tích Load Test Report bằng wrk

Tài liệu này hướng dẫn cách đọc, hiểu và so sánh kết quả load test được tạo bởi công cụ **wrk** cho ba triển khai Spring Boot: Traditional MVC, Virtual Threads, và WebFlux.

---

## Mục lục

1. [Cấu trúc output của wrk](#1-cấu-trúc-output-của-wrk)
2. [Giải thích từng chỉ số](#2-giải-thích-từng-chỉ-số)
3. [Các loại lỗi thường gặp](#3-các-loại-lỗi-thường-gặp)
4. [Quy trình chạy test để so sánh](#4-quy-trình-chạy-test-để-so-sánh)
5. [So sánh kết quả giữa ba service](#5-so-sánh-kết-quả-giữa-ba-service)
6. [Cách đọc từng kịch bản test](#6-cách-đọc-từng-kịch-bản-test)
7. [Checklist phân tích kết quả](#7-checklist-phân-tích-kết-quả)
8. [Ví dụ phân tích thực tế](#8-ví-dụ-phân-tích-thực-tế)

---

## 1. Cấu trúc output của wrk

Khi chạy `wrk -t4 -c100 -d30s http://${LB_IP}/mvc/api/query`, output có dạng:

```
Running 30s test @ http://192.168.1.200/mvc/api/query
  4 threads and 100 connections

  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    38.62ms   42.79ms 383.68ms   87.56%
    Req/Sec   808.92    111.48     1.03k    70.59%

  Latency Distribution
     50%   19.47ms
     75%   45.23ms
     90%   99.84ms
     99%  186.78ms

  97044 requests in 30.02s, 21.09MB read
  Socket errors: connect 0, read 0, write 0, timeout 12
Requests/sec:   3232.15
Transfer/sec:    719.32KB
```

---

## 2. Giải thích từng chỉ số

### 2.1 Thông tin chạy test

| Dòng | Ý nghĩa |
|------|---------|
| `Running 30s test @ URL` | Test chạy 30 giây tới endpoint đó |
| `4 threads and 100 connections` | 4 luồng worker, duy trì 100 kết nối HTTP đồng thời |

> **Lưu ý**: `-t4` là số luồng của wrk (nên ≤ số CPU của máy chạy wrk), không liên quan đến số thread trong service. `-c100` là số concurrent connections thực sự gửi request.

---

### 2.2 Thread Stats — Latency (độ trễ)

```
Thread Stats   Avg      Stdev     Max   +/- Stdev
  Latency    38.62ms   42.79ms 383.68ms   87.56%
```

| Chỉ số | Ký hiệu | Ý nghĩa |
|--------|---------|---------|
| **Avg** | `38.62ms` | Trung bình thời gian phản hồi. Dễ bị skew bởi outlier. |
| **Stdev** | `42.79ms` | Độ lệch chuẩn. **Stdev cao → hành vi không ổn định.** |
| **Max** | `383.68ms` | Latency cao nhất ghi nhận được — thường xảy ra khi GC pause hoặc thread pool đầy. |
| **+/- Stdev** | `87.56%` | % request nằm trong khoảng `Avg ± Stdev`. Càng cao càng ổn định. |

> **Cảnh báo**: Nếu `Stdev > Avg/2`, service đang có vấn đề về hiệu năng ổn định (thread starvation, GC pressure, cold start).

---

### 2.3 Thread Stats — Req/Sec (throughput mỗi thread)

```
Req/Sec   808.92    111.48     1.03k    70.59%
```

| Chỉ số | Ý nghĩa |
|--------|---------|
| `808.92` | Trung bình số request mỗi thread xử lý được mỗi giây |
| `111.48` | Độ lệch chuẩn — thấp = hiệu năng ổn định |
| `1.03k` | Peak throughput của một thread |

> Tổng throughput = `Req/Sec Avg × số threads`. Nhưng hãy dùng `Requests/sec` ở cuối output vì đó là con số chính xác nhất.

---

### 2.4 Latency Distribution (phân phối độ trễ)

```
Latency Distribution
   50%   19.47ms   ← P50 (median)
   75%   45.23ms   ← P75
   90%   99.84ms   ← P90
   99%  186.78ms   ← P99
```

Đây là các **percentile** — chỉ số quan trọng nhất để đánh giá UX thực tế:

| Percentile | Ý nghĩa | Dùng để |
|-----------|---------|---------|
| **P50** | 50% request hoàn thành dưới thời gian này. Gần với trải nghiệm người dùng trung bình. | Baseline so sánh |
| **P90** | 90% request hoàn thành dưới thời gian này. Phản ánh tail latency. | SLA thực tế |
| **P99** | 99% request hoàn thành dưới thời gian này. Phản ánh worst-case thường gặp. | Detect bottleneck |
| **Max** | Request chậm nhất. Có thể do GC, thread starvation, network spike. | Debug outlier |

> **Khoảng cách P99 - P50**: Khoảng cách lớn cho thấy có **tail latency problem** — thường gặp ở MVC khi thread pool bị saturate.

---

### 2.5 Tổng kết cuối (Summary)

```
97044 requests in 30.02s, 21.09MB read
Socket errors: connect 0, read 0, write 0, timeout 12
Requests/sec:   3232.15
Transfer/sec:    719.32KB
```

| Chỉ số | Ý nghĩa |
|--------|---------|
| `97044 requests in 30.02s` | Tổng request hoàn thành thành công trong toàn bộ thời gian test |
| `21.09MB read` | Tổng dữ liệu nhận được — kiểm tra xem response có bị cắt không |
| **`Requests/sec`** | **Throughput tổng thể — chỉ số quan trọng nhất để so sánh** |
| `Transfer/sec` | Bandwidth tiêu thụ |

---

## 3. Các loại lỗi thường gặp

```
Socket errors: connect 0, read 2, write 0, timeout 12
```

| Loại lỗi | Nguyên nhân thường gặp | Cần xem xét |
|----------|------------------------|-------------|
| `connect` | Port không mở, service đã crash, connection limit đạt ngưỡng OS | `kubectl get pods`, `ss -s` |
| `read` | Service trả về response không hợp lệ hoặc đóng kết nối sớm | Logs pod |
| `write` | Network buffer đầy, client-side issue | Hiếm gặp |
| `timeout` | Request mất quá lâu, vượt wrk timeout mặc định (2s) | Thread pool saturation, query chậm |

> **Quy tắc**: Nếu `timeout > 1%` tổng requests → service đang bị quá tải. Cần giảm `-c` hoặc tăng resource.

---

## 4. Quy trình chạy test để so sánh

### 4.1 Lấy IP của Ingress

```bash
LB_IP=$(kubectl get ingress spring-performance-ingress \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $LB_IP"
```

### 4.2 Warm-up (bắt buộc trước khi đo)

JVM cần được JIT-compiled (Just-In-Time: trình biên dịch tối ưu hóa các code path "nóng" ở runtime) trước khi đo chính xác. Nếu bỏ qua bước này, các số đo đầu tiên sẽ bao gồm overhead của quá trình biên dịch và class loading, khiến kết quả bị thiên lệch. Chạy warm-up 30-60 giây:

```bash
# Warm-up — không lưu kết quả
wrk -t4 -c50 -d30s http://${LB_IP}/mvc/api/query
wrk -t4 -c50 -d30s http://${LB_IP}/virtual/api/query
wrk -t4 -c50 -d30s http://${LB_IP}/webflux/api/query
sleep 30   # Cho JVM ổn định sau warm-up
```

### 4.3 Chạy test chính thức (khuyến nghị)

```bash
# Kịch bản 1: Concurrency thấp — đo overhead per-request
wrk -t4 -c50 -d60s http://${LB_IP}/mvc/api/query
wrk -t4 -c50 -d60s http://${LB_IP}/virtual/api/query
wrk -t4 -c50 -d60s http://${LB_IP}/webflux/api/query

# Kịch bản 2: Concurrency trung bình — điểm thể hiện rõ sự khác biệt
wrk -t4 -c200 -d60s http://${LB_IP}/mvc/api/query
wrk -t4 -c200 -d60s http://${LB_IP}/virtual/api/query
wrk -t4 -c200 -d60s http://${LB_IP}/webflux/api/query

# Kịch bản 3: Blocking I/O với độ trễ 500ms — điểm mà MVC bắt đầu đuối
wrk -t4 -c200 -d60s http://${LB_IP}/mvc/api/query/500
wrk -t4 -c200 -d60s http://${LB_IP}/virtual/api/query/500
wrk -t4 -c200 -d60s http://${LB_IP}/webflux/api/query/500

# Kịch bản 4: CPU-bound — kiểm tra hiệu quả scheduler
wrk -t4 -c100 -d60s http://${LB_IP}/mvc/api/cpu/100
wrk -t4 -c100 -d60s http://${LB_IP}/virtual/api/cpu/100
wrk -t4 -c100 -d60s http://${LB_IP}/webflux/api/cpu/100
```

### 4.4 Dùng script tự động

```bash
# Test đầy đủ với tất cả kịch bản
# Tham số: [threads] [connections] [duration_seconds] [base_url]
#   threads=4          → số luồng worker của wrk (≤ số CPU máy chạy wrk)
#   connections=200    → số HTTP connections đồng thời
#   duration=60        → thời gian mỗi kịch bản test (giây)
./load-test-wrk.sh 4 200 60 http://${LB_IP}

# Kết quả lưu vào thư mục load-test-results-YYYYMMDD-HHMMSS/
```

---

## 5. So sánh kết quả giữa ba service

### 5.1 Bảng so sánh nhanh

Tạo bảng so sánh từ kết quả của từng kịch bản:

| Metric | Traditional MVC | Virtual Threads | WebFlux |
|--------|----------------|-----------------|---------|
| Requests/sec (c=50) | | | |
| Requests/sec (c=200) | | | |
| Requests/sec (c=200, 500ms delay) | | | |
| P50 Latency | | | |
| P99 Latency | | | |
| Timeout errors | | | |

### 5.2 Trích xuất tự động từ file kết quả

```bash
RESULTS_DIR="load-test-results-YYYYMMDD-HHMMSS"  # thay bằng tên thư mục thực tế

echo "=== Throughput (Requests/sec) ==="
echo -n "MVC:     "; grep "Requests/sec:" $RESULTS_DIR/mvc-traditional.txt
echo -n "Virtual: "; grep "Requests/sec:" $RESULTS_DIR/virtual-threads.txt
echo -n "WebFlux: "; grep "Requests/sec:" $RESULTS_DIR/webflux.txt

echo ""
echo "=== P99 Latency ==="
echo -n "MVC:     "; grep "99%" $RESULTS_DIR/mvc-traditional.txt
echo -n "Virtual: "; grep "99%" $RESULTS_DIR/virtual-threads.txt
echo -n "WebFlux: "; grep "99%" $RESULTS_DIR/webflux.txt

echo ""
echo "=== Errors ==="
echo -n "MVC:     "; grep "Socket errors:" $RESULTS_DIR/mvc-traditional.txt || echo "no errors"
echo -n "Virtual: "; grep "Socket errors:" $RESULTS_DIR/virtual-threads.txt || echo "no errors"
echo -n "WebFlux: "; grep "Socket errors:" $RESULTS_DIR/webflux.txt || echo "no errors"
```

### 5.3 Kỳ vọng theo từng kịch bản

#### Kịch bản I/O với độ trễ (500ms delay, concurrency cao)

| Service | Kỳ vọng | Lý do |
|---------|---------|-------|
| **Traditional MVC** | Throughput thấp, timeout nhiều khi `-c > thread pool size` | Mỗi request chiếm 1 thread Tomcat trong 500ms → thread pool (200) bị saturate ở ~400 rps |
| **Virtual Threads** | Throughput tương đương hoặc cao hơn MVC | JVM không bị block — virtual thread "park" thay vì chiếm carrier thread |
| **WebFlux** | Throughput cao nhất, P99 ổn định | Non-blocking I/O — event loop không bị giữ trong lúc chờ I/O |

#### Kịch bản CPU-bound

| Service | Kỳ vọng | Lý do |
|---------|---------|-------|
| **Traditional MVC** | Tốt — throughput tỷ lệ với CPU | Đơn giản, mỗi thread = 1 CPU core |
| **Virtual Threads** | Tương đương MVC | Carrier pool = CPU cores, không bypass CPU constraint |
| **WebFlux** | Tốt — ít overhead hơn do ít context-switch | Event loop hiệu quả với CPU-bound work |

---

## 6. Cách đọc từng kịch bản test

### 6.1 Test `/api/query` — Baseline I/O

```
Kết quả tốt:
  Requests/sec: > 2000
  P99 Latency:  < 100ms
  Errors:       0

Dấu hiệu cần chú ý:
  - Requests/sec thấp hơn kỳ vọng → xem CPU/memory usage pod
  - P99 cao bất thường → GC pause (thêm -Xlog:gc* vào JAVA_TOOL_OPTIONS)
  - Errors > 0 → service đang bị quá tải
```

### 6.2 Test `/api/query/500` — I/O Blocking (500ms)

Đây là kịch bản **quan trọng nhất** để phân biệt ba mô hình threading:

```
Với -c200 (200 connections):

MVC Traditional (Tomcat 200 threads):
  → Tối đa 200 req đang xử lý song song × (1/0.5s) = ~400 req/s lý thuyết
  → Nếu -c > 200, các request xếp hàng → timeout tăng vọt

Virtual Threads:
  → Không bị giới hạn bởi thread pool
  → Throughput ≈ capacity của downstream (DB, API) không phải thread pool

WebFlux:
  → Event loop không bị block → throughput cao nhất trong I/O-bound scenario
  → P99 ổn định nhất
```

**Dấu hiệu MVC đang saturated:**
```
Socket errors: connect 0, read 0, write 0, timeout 50+
Requests/sec: thấp hơn nhiều so với Virtual/WebFlux
P99: > 2000ms (wrk timeout default)
```

### 6.3 Test `/api/cpu/{durationMs}` — CPU Bound

```
Với cpuMs=100 (mỗi request dùng 100ms CPU):

Cả 3 service đều bị giới hạn bởi CPU limit (2 CPUs/pod × 4 pods = 8 CPUs tổng).
Throughput lý thuyết tối đa = 8 CPUs / 0.1s = 80 req/s per pod × 4 = 320 req/s

Nếu Requests/sec >> 320 → workload không thực sự CPU-bound như cấu hình
Nếu Requests/sec << 320 → overhead từ threading model đang ăn vào throughput
```

### 6.4 Test `/api/stress` — Kết hợp I/O + CPU

```
Kịch bản khó nhất — phân biệt rõ ràng nhất hiệu quả tổng thể:
  - MVC: dễ bị saturate khi cả I/O lẫn CPU đều block threads
  - Virtual Threads: I/O không block carrier → tốt hơn MVC
  - WebFlux: tốt nhất trong cả hai chiều
```

---

## 7. Checklist phân tích kết quả

Khi nhận được file kết quả, kiểm tra theo thứ tự:

### ✅ Bước 1: Kiểm tra tính hợp lệ của test

- [ ] Test đã chạy đủ thời gian (duration = số giây yêu cầu)?
- [ ] Không có error kết nối (`connect errors = 0`)?
- [ ] Transfer/sec hợp lý (không quá thấp → response bị trống)?

### ✅ Bước 2: So sánh Throughput (Requests/sec)

- [ ] Service nào có throughput cao nhất ở từng kịch bản?
- [ ] Throughput có tăng tuyến tính khi tăng `-c`? (Nếu không → bottleneck)
- [ ] Chênh lệch giữa 3 service có phù hợp với lý thuyết?

### ✅ Bước 3: Phân tích Latency

- [ ] P50 (median): Service nào nhanh nhất trong trường hợp bình thường?
- [ ] P99: Service nào ổn định nhất dưới tải cao?
- [ ] Khoảng cách P99 - P50: Nhỏ = ổn định, Lớn = có tail latency problem

### ✅ Bước 4: Kiểm tra Lỗi

- [ ] `timeout errors` có > 0 không? → Service đang quá tải ở mức `-c` này
- [ ] `read errors` có không? → Xem log pod

### ✅ Bước 5: Đối chiếu với Resource Metrics

```bash
# Xem CPU và Memory usage trong quá trình test
kubectl top pods --containers

# Xem số request đang xử lý (chỉ dùng khi đang test)
curl -s http://${LB_IP}/mvc/actuator/prometheus | grep http_server_requests_active
curl -s http://${LB_IP}/virtual/actuator/prometheus | grep http_server_requests_active
curl -s http://${LB_IP}/webflux/actuator/prometheus | grep reactor_netty_http_server_connections_active
```

---

## 8. Ví dụ phân tích thực tế

### Ví dụ output — Kịch bản I/O 500ms delay, -c200

**Traditional MVC:**
```
Running 60s test @ http://192.168.1.200/mvc/api/query/500
  4 threads and 200 connections

  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   523.45ms  312.18ms    2.00s   78.32%
    Req/Sec    92.14     48.76    231.00    65.00%

  Latency Distribution
     50%  501.23ms
     90%  921.45ms
     99%    2.00s      ← gần bằng wrk default timeout → service đang saturated

  22063 requests in 60.02s, 5.32MB read
  Socket errors: connect 0, read 0, write 0, timeout 342   ← 342 timeouts!
Requests/sec:    367.59
Transfer/sec:     90.73KB
```

**Phân tích**: Tomcat thread pool (200 threads) bị saturate. 200 threads × (1/0.5s) = 400 req/s tối đa. Thực tế đạt 367 req/s. Timeout 342 = requests không được phục vụ kịp.

---

**Virtual Threads:**
```
Running 60s test @ http://192.168.1.200/virtual/api/query/500
  4 threads and 200 connections

  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   511.23ms   45.12ms  743.21ms   95.12%   ← Stdev thấp = ổn định
    Req/Sec    98.45     12.34    124.00    82.00%

  Latency Distribution
     50%  502.34ms
     90%  542.11ms
     99%  623.45ms     ← P99 thấp hơn MVC rất nhiều

  23616 requests in 60.01s, 5.69MB read
  Socket errors: connect 0, read 0, write 0, timeout 0    ← Không có timeout!
Requests/sec:    393.54
Transfer/sec:     97.18KB
```

**Phân tích**: Throughput cao hơn MVC 7%, không có timeout, P99 thấp hơn 3x. Virtual threads không bị block carrier threads khi đợi I/O.

---

**WebFlux:**
```
Running 60s test @ http://192.168.1.200/webflux/api/query/500
  4 threads and 200 connections

  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   503.21ms   22.45ms  612.34ms   98.45%   ← Rất ổn định
    Req/Sec   100.23      8.12    119.00    90.00%

  Latency Distribution
     50%  501.45ms
     90%  517.23ms
     99%  558.34ms     ← P99 thấp nhất trong 3 service

  24049 requests in 60.01s, 5.79MB read
  Socket errors: connect 0, read 0, write 0, timeout 0
Requests/sec:    400.76
Transfer/sec:     98.89KB
```

**Phân tích**: Throughput cao nhất. P99 rất gần P50 — hành vi cực kỳ ổn định. Event loop không bị giữ trong khi chờ I/O.

---

### Tổng kết ví dụ

| Metric | MVC | Virtual Threads | WebFlux | Nhận xét |
|--------|-----|-----------------|---------|----------|
| Requests/sec | 367 | 393 (+7%) | 401 (+9%) | WebFlux tốt nhất |
| P50 Latency | 501ms | 502ms | 501ms | Tương đương |
| P99 Latency | **2000ms** | 623ms | 558ms | MVC có vấn đề nghiêm trọng |
| Timeouts | **342** | 0 | 0 | MVC đang saturated |
| Stdev | 312ms | 45ms | 22ms | WebFlux ổn định nhất |

> **Kết luận**: Với I/O-bound workload và concurrency cao, Virtual Threads và WebFlux vượt trội so với MVC truyền thống. Sự khác biệt càng rõ khi tăng `-c` (concurrency) hoặc tăng delay của I/O.

---

## Tài liệu tham khảo

- [wrk GitHub Repository](https://github.com/wg/wrk)
- [TESTING-GUIDE.md](./TESTING-GUIDE.md) — Hướng dẫn chạy test trong repository này
- [deployment/kubernetes/README.md](./deployment/kubernetes/README.md) — Hướng dẫn deploy lên Kubernetes
- [load-test-wrk.sh](./load-test-wrk.sh) — Script tự động hóa load test
