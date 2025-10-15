import React from "react";
import { Link } from "react-router-dom";

function BottomWarning({ lable, buttonText, link }) {
  return (
    <div>
      <div className=" text-slate-600 font-medium">{lable}</div>
      <div>
        <Link className="pointer underline pl-1 cursor-pointer" to={link}>
          {buttonText}
        </Link>
      </div>
    </div>
  );
}

export default BottomWarning;
