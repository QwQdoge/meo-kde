"""Notification center presents the NotificationManager features KDE supports."""

from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
VIEW = (ROOT / "qml/MeoKDE/NotificationCenterView.qml").read_text(encoding="utf-8")


class NotificationFeatureContract(unittest.TestCase):
    def test_job_progress_details_and_controls(self):
        for token in (
            "MeoProgressBar", "jobDetails", "totalBytes", "processedBytes", "speed",
            "formatRemaining", "descriptionLabel1", "descriptionValue2", "jobErrorText",
            "resumeJob", "suspendJob", "killJob", "effectiveDestUrl",
        ):
            with self.subTest(token=token):
                self.assertIn(token, VIEW)

    def test_clicking_opens_default_action_or_the_posting_application(self):
        self.assertIn("function activate()", VIEW)
        self.assertIn("invokeDefaultAction", VIEW)
        self.assertIn('"applications:" + id + ".desktop"', VIEW)
        self.assertIn("onClicked: notificationCard.activate()", VIEW)

    def test_images_attachments_actions_and_reply(self):
        for token in (
            "notificationImage", "Kirigami.Icon", "attachedUrls", "defaultActionLabel",
            "invokeAction", "root.notifications.reply", "Qt.openUrlExternally",
        ):
            with self.subTest(token=token):
                self.assertIn(token, VIEW)


if __name__ == "__main__":
    unittest.main()
