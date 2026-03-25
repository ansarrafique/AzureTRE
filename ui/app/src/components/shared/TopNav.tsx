import React from "react";
import { getTheme, mergeStyles, Stack } from "@fluentui/react";
import { Link } from "react-router-dom";
import { UserMenu } from "./UserMenu";
import { NotificationPanel } from "./notifications/NotificationPanel";
import config from "../../config.json";

export const TopNav: React.FunctionComponent = () => {
  return (
    <>
      <div className={contentClass}>
        <Stack horizontal verticalAlign="center" styles={{ root: { width: "100%" } }}>
          <Stack.Item>
            <Link
              to="/"
              className="tre-home-link"
              style={{
                display: "inline-flex",
                alignItems: "center",
                textDecoration: "none",
              }}
            >
              <img
                src="/images/oxford-uni-logo.png"
                alt="Logo"
                width={40}
                height={40}
                style={{ marginRight: "10px" }}
              />
              <span
                style={{
                  display: "inline-flex",
                  flexDirection: "column",
                  lineHeight: 1.1,
                  color: "#ffffff",
                }}
              >
                <span style={{ fontSize: "0.8rem", fontWeight: 500 }}>
                  University of Oxford
                </span>
                <span style={{ fontSize: "1.05rem", fontWeight: 600 }}>
                  Trusted Research Environment
                </span>
              </span>
            </Link>
          </Stack.Item>
          <Stack.Item style={{ marginLeft: "auto" }}>
            <Stack horizontal verticalAlign="center" tokens={{ childrenGap: 16 }}>
              <Stack.Item>
                <NotificationPanel />
              </Stack.Item>
              <Stack.Item>
                <UserMenu />
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </div>
    </>
  );
};

const theme = getTheme();
const contentClass = mergeStyles([
  {
    backgroundColor: "#002147",
    color: "#ffffff",
    padding: "0 24px",
    height: 56,
    display: "flex",
    alignItems: "center",
    boxShadow: "0 2px 4px rgba(0, 0, 0, 0.1)",
  },
]);
