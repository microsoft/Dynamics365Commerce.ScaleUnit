/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */

import * as Dialogs from "PosApi/Create/Dialogs";
import { ObjectExtensions } from "PosApi/TypeExtensions";

type DialogResolve = (result: any) => void;
type DialogReject = (reason: any) => void;

export default class PingResultDialog extends Dialogs.ExtensionTemplatedDialogBase {
    private _resolve: DialogResolve;
    private _pingUnboundGetResult: boolean;
    private _pingUnboundPostResult: boolean;

    constructor() {
        super();
    }

    public onReady(element: HTMLElement): void {
        let getPingResult = element.querySelector("#UnboundGetResult") as HTMLSpanElement;
        getPingResult.textContent = this._pingUnboundGetResult ? "Success!" : "Failed.";
        let postPingResult = element.querySelector("#UnboundPostResult") as HTMLSpanElement;
        postPingResult.textContent = this._pingUnboundPostResult ? "Success!" : "Failed.";
    }

    public open(pingUnboundGetResult: boolean, pingUnboundPostResult: boolean): Promise<void> {
        let promise: Promise<void> = new Promise((resolve: DialogResolve, reject: DialogReject) => {
            this._resolve = resolve;
            this._pingUnboundGetResult = pingUnboundGetResult;
            this._pingUnboundPostResult = pingUnboundPostResult;
            this.openDialog({
                title: "Ping Test Results",
                button1: {
                    id: "btnOk",
                    label: this.context.resources.getString("string_2005"),
                    isPrimary: true,
                    onClick: this.closeDialogHandler.bind(this)
                },
                onCloseX: () => this.closeDialogHandler()
            });
        });

        return promise;
    }

    private closeDialogHandler(): boolean {
        this.resolvePromise();
        return true;
    }

    private resolvePromise(): void {
        if (ObjectExtensions.isFunction(this._resolve)) {
            this._resolve(null);
            this._resolve = null;
        }
    }
}
