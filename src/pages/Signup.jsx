import React, { useState } from "react";
import SubHeading from "../components/SubHeading";
import InputFields from "../components/InputFields";
import Button from "../components/Button";
import BottomWarning from "../components/BottomWarning";
import Heading from "../components/Heading";
import axios from "axios";
import { Link, useNavigate } from "react-router-dom";

let backendUrl;

// Fetch runtime configuration
async function fetchConfig() {
  try {
    const response = await fetch("/config.json");
    const config = await response.json();
    backendUrl = config.backendUrl || backendUrl;
  } catch (error) {
    console.error(
      "Failed to load runtime config.json, using default backend URL."
    );
    backendUrl = "http://localhost:3000";
  }
}

// Load configuration before making any API calls
fetchConfig();

function SignUpCard() {
  const navigate = useNavigate();
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [userName, setUserName] = useState("");
  const [password, setPassword] = useState("");

  return (
    <div>
      <div className=" flex-col justify-center m-auto border-slate-400 border w-fit p-5 items-center rounded-lg bg-white my-20">
        <Heading label={"Sign Up"} />
        <SubHeading label={"Enter your information to create an account"} />
        <InputFields
          label={"First Name"}
          placeholder={"Darshana"}
          onChange={(e) => {
            const firstName = e.target.value;
            setFirstName(firstName);
          }}
        ></InputFields>
        <InputFields
          label={"Last Name"}
          placeholder={"Lakhan"}
          onChange={(e) => {
            const lastName = e.target.value;
            setLastName(lastName);
          }}
        ></InputFields>
        <InputFields
          label={"E-mail"}
          placeholder={"abc@gmail.com"}
          onChange={(e) => {
            const userName = e.target.value;
            setUserName(userName);
          }}
        ></InputFields>
        <InputFields
          label={"Password"}
          placeholder={""}
          onChange={(e) => {
            const password = e.target.value;
            setPassword(password);
          }}
        ></InputFields>
        <Button
          label={"Sign Up"}
          onClick={async () => {
            console.log(backendUrl);
            const response = await axios.post(
              // "http://localhost:3000/api/vi/user/signup",
              `${backendUrl}/api/vi/user/signup`,
              {
                firstName,
                lastName,
                userName,
                password,
              }
            );

            localStorage.setItem("token", response.data.token);
            navigate("/dashboard");
          }}
        />
        <div className="flex">
          <BottomWarning lable={"Already Have an account ?"}></BottomWarning>
          <Link
            className="font-md text-blue-600 px-2 hover:text-blue-300"
            to={"/signin"}
          >
            Log In
          </Link>
        </div>
      </div>
    </div>
  );
}

export default SignUpCard;
