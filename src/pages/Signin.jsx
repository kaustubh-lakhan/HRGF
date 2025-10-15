import React, { useState } from "react";
import Heading from "../components/Heading";
import SubHeading from "../components/SubHeading";
import InputFields from "../components/InputFields";
import Button from "../components/Button";
import BottomWarning from "../components/BottomWarning";
import { Link, useNavigate } from "react-router-dom";
import axios from "axios";

function Signin() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const navigate = useNavigate();
  return (
    <div className=" flex-col justify-center m-auto border-slate-400 border w-fit p-5 items-center rounded-lg bg-white my-20">
      <Heading label={"Sign In"}></Heading>
      <SubHeading
        label={"Enter your credentials to acess your account"}
      ></SubHeading>
      <InputFields
        placeholder={"abc@gmail.com"}
        label={"E-Mail"}
        onChange={(e) => {
          const Email = e.target.value;
          setEmail(Email);
        }}
      ></InputFields>
      <InputFields
        placeholder={"XXXXX"}
        label={"Password"}
        onChange={(e) => {
          const password = e.target.value;
          setPassword(password);
        }}
      ></InputFields>
      <Button
        label={"Sign In"}
        onClick={async () => {
          console.log(email, password);
          const response = await axios.post(
            "http://host.docker.internal:3000/api/vi/user/signin",
            {
              userName: email,
              password,
            }
          );
          localStorage.setItem("token", response.data.token);
          navigate("/dashboard");
        }}
      ></Button>
      <div className="flex">
        <BottomWarning lable={"Dont have account ?"}></BottomWarning>
        <Link
          className="font-md text-blue-600 px-2 hover:text-blue-300"
          to={"/signup"}
        >
          Sign Up
        </Link>
      </div>
    </div>
  );
}

export default Signin;
