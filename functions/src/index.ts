import * as admin from "firebase-admin";
import {cancelOrder, createOrder} from "./orders/order_functions";

admin.initializeApp();

export {createOrder, cancelOrder};