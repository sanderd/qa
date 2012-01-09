#!/usr/bin/env python

import unittest
import time
import sys
import common

selenium_url = "http://localhost:8080/"
selenium_port = 4444

class OSDashboardTestCase(common.SeleniumTestCase):
    def setUp(self):
        self.set_up_selenium(selenium_url, selenium_port)
        common.login_to_horizon(self)

    def tearDown(self):
        common.logout_of_horizon(self)
        self.stop_selenium()

    def _terminate_instance(self):
        """tries to terminate an instance,
        but assumes only one instance is running"""
        sel = self.selenium
        sel.click("link=Instances")
        self.wait_for_page_to_load()

        terminate_link_id = "terminate_1"
        all_links = sel.get_all_buttons()
        for link_id in all_links:
            if link_id.find("terminate_") != -1:
                terminate_link_id = link_id
                break

        sel.click(terminate_link_id)
        self.failUnless(sel.get_confirmation().startswith(
            "Are you sure you want to terminate the Instance:"))
        self.wait_for_page_to_load()

    @common.snapshot_on_error
    def test_1_terminate_instance(self):
        self._terminate_instance()
        self.wait_for_text("There are currently no instances.")


if __name__ == "__main__":
    selenium_url = sys.argv[1]
    selenium_port = sys.argv[2]
    common.screenshot_dir = sys.argv[3]
    # Ignore command line arguments
    unittest.main(argv=[sys.argv[0]])
