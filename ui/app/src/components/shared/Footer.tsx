import React from "react";
import { AnimationClassNames, getTheme, mergeStyles } from "@fluentui/react";

export const Footer: React.FunctionComponent = () => {
  const year = new Date().getFullYear();

  return (
    <div className={contentClass}>
      © {year} University of Oxford. Research Services, 5 Worcester Street,
      Oxford, OX1 2BX · Migrating to{" "}
      <a
        href="https://workspace.oxtre.ox.ac.uk"
        target="_blank"
        rel="noreferrer"
      >
        workspace.oxtre.ox.ac.uk
      </a>{" "}
      soon · Powered by AzureTRE
    </div>
  );
};

const theme = getTheme();
const contentClass = mergeStyles([
  {
    alignItems: "center",
    backgroundColor: "#002147",
    color: theme.palette.white,
    lineHeight: "34px",
    padding: "0 16px",
    fontSize: "12px",
    textAlign: "center",
  },
  AnimationClassNames.scaleUpIn100,
]);