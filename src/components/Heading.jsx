import React, { useState } from "react";

function Heading({ label }) {
  return (
    <div className="text-3xl font-bold p-2 flex justify-center">{label}</div>
  );
}

export default Heading;
