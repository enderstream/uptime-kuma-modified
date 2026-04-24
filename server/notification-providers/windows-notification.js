const NotificationProvider = require("./notification-provider");
const notifier = require("node-notifier");

class WindowsNotification extends NotificationProvider {
    name = "windowsNotification";

    /**
     * @inheritdoc
     */
    async send(notification, msg, monitorJSON = null, heartbeatJSON = null) {
        const okMsg = "Sent Successfully.";

        return new Promise((resolve, reject) => {
            notifier.notify(
                {
                    title: "소프트웨어 구매 관리 시스템",
                    message: msg,
                    sound: true,
                    wait: false,
                },
                (error) => {
                    if (error) {
                        reject(new Error(`Windows Notification failed: ${error.message}`));
                    } else {
                        resolve(okMsg);
                    }
                }
            );
        });
    }
}

module.exports = WindowsNotification;
