importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js");

try {
  importScripts("/firebase-config.js");
} catch (error) {
  self.schoolDeskFirebaseConfig = null;
}

if (self.schoolDeskFirebaseConfig) {
  firebase.initializeApp(self.schoolDeskFirebaseConfig);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage(function (payload) {
    const notification = payload.notification || {};
    const title = notification.title || payload.data?.title || "SchoolDesk";
    const options = {
      body: notification.body || payload.data?.body || "",
      icon: "/icons/Icon-192.png",
      badge: "/icons/Icon-192.png",
      data: payload.data || {}
    };

    self.registration.showNotification(title, options);
  });
}
