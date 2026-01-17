# WatchTower

A macOS menu bar app for monitoring API endpoint health. Keep an eye on your services with automated health checks and instant notifications when something goes wrong.

## Features

- **API Health Monitoring** - Automatically check endpoints at configurable intervals (5 minutes to daily)
- **Menu Bar Integration** - Quick status overview from your menu bar with visual indicators
- **Desktop Notifications** - Get notified immediately when an endpoint fails or recovers
- **cURL Import** - Paste cURL commands to quickly add endpoints with headers and body
- **Dashboard & List Views** - View all endpoints at a glance or dive into details
- **Bulk Operations** - Enable, disable, check, or delete multiple endpoints at once
- **Response Tracking** - Monitor response times and status codes over time

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/WatchTower.git
   ```

2. Open `WatchTower.xcodeproj` in Xcode

3. Build and run (Cmd+R)

## Usage

### Adding an Endpoint

1. Click the **+** button in the toolbar
2. Choose between manual entry or cURL import
3. Configure the endpoint name, URL, HTTP method, headers, and polling interval
4. Save to start monitoring

### Monitoring

- **Dashboard View** - Grid overview of all endpoint statuses
- **List View** - Detailed list with response times and last check timestamps
- **Menu Bar** - Quick status indicator (antenna icon changes when endpoints fail)

### Polling Intervals

| Interval | Description |
|----------|-------------|
| 5 minutes | Real-time monitoring for critical services |
| 15 minutes | Default balanced option |
| Hourly | Low-priority endpoints |
| Every 12 hours | Daily-ish checks |
| Daily | Minimal monitoring |

## Project Structure

```
WatchTower/
├── Models/
│   ├── APIEndpoint.swift      # Core endpoint model
│   ├── HealthCheckResult.swift # Check result storage
│   ├── HTTPMethod.swift        # GET, POST, etc.
│   ├── EndpointStatus.swift    # healthy, failing, unknown
│   └── PollingInterval.swift   # Timing options
├── Services/
│   ├── HealthCheckService.swift   # Performs health checks
│   ├── NetworkService.swift       # HTTP requests
│   ├── SchedulerService.swift     # Manages check timing
│   ├── NotificationService.swift  # Desktop notifications
│   └── CurlParserService.swift    # cURL command parsing
└── Views/
    ├── MainView.swift
    ├── Dashboard/
    ├── Endpoints/
    ├── AddEndpoint/
    └── MenuBar/
```

## License

MIT
