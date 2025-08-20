const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendWelcomeNotification = onDocumentCreated(
    {
      region: "australia-southeast1", // ✅ Set your preferred region
    },
    "User/{userId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("❌ No Firestore snapshot data");
        return;
      }

      const data = snap.data();
      const fcmToken = data && data.fcmToken;
      const email = (data && data.email) || "a new user";

      if (!fcmToken) {
        console.log("❌ No FCM token found for user:", event.params.userId);
        return;
      }

      const message = {
        notification: {
          title: "Welcome to RouteGen! 🎉",
          body:
           "Hey ! Every step counts—reach fitness goals together",
        },
        token: fcmToken,
      };

      try {
        await admin.messaging().send(message);
        console.log(
            `✅ Notification sent to ${email} (${event.params.userId})`,
        );
      } catch (error) {
        console.error("🔥 Error sending notification:", error);
      }
    },
);
