/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */

import * as Dialogs from "PosApi/Create/Dialogs";
import { Entities } from "../../../DataService/DataServiceEntities.g";
import { ObjectExtensions } from "PosApi/TypeExtensions";

type DialogResolve = (updatedEntity: Entities.ExampleEntity) => void;
type DialogReject = (reason: any) => void;

export default class ExampleCreateDialog extends Dialogs.ExtensionTemplatedDialogBase {
    private _resolve: DialogResolve;
    private _data: Entities.ExampleEntity;

    constructor() {
        super();
        this._data = {
            UnusualEntityId: -1,
            IntData: 0,
            StringData: "",
            ExtensionProperties: [{
                Key: "customExtensionProp",
                Value: {}
            }]
        };
    }

    public onReady(element: HTMLElement): void {
        let intDataInput: HTMLInputElement = element.querySelector("#intData") as HTMLInputElement;
        intDataInput.onchange = () => { this._data.IntData = intDataInput.valueAsNumber; };

        let stringDataInput: HTMLInputElement = element.querySelector("#stringData") as HTMLInputElement;
        stringDataInput.onchange = () => { this._data.StringData = stringDataInput.value; };

        let extensionPropertyStringDataInput: HTMLInputElement = element.querySelector("#extensionPropertyStringData") as HTMLInputElement;
        extensionPropertyStringDataInput.onchange = () => {
            this._data.ExtensionProperties[0].Value.StringValue = extensionPropertyStringDataInput.value;
        };
    }

    public open(): Promise<Entities.ExampleEntity> {
        let promise: Promise<Entities.ExampleEntity> = new Promise((resolve: DialogResolve, reject: DialogReject) => {
            this._resolve = resolve;
            let option: Dialogs.ITemplatedDialogOptions = {
                title: "Create Example Entity",
                button1: {
                    id: "btnCreate",
                    label: this.context.resources.getString("string_2001"),
                    isPrimary: true,
                    onClick: this.btnUpdateClickHandler.bind(this)
                },
                button2: {
                    id: "btnCancel",
                    label: this.context.resources.getString("string_2004"),
                    onClick: this.btnCancelClickHandler.bind(this)
                },
                onCloseX: () => this.btnCancelClickHandler()
            };

            this.openDialog(option);
        });

        return promise;
    }

    private btnUpdateClickHandler(): boolean {
        this.resolvePromise(this._data);
        return true;
    }

    private btnCancelClickHandler(): boolean {
        this.resolvePromise(null);
        return true;
    }

    private resolvePromise(editResult: Entities.ExampleEntity): void {
        if (ObjectExtensions.isFunction(this._resolve)) {
            this._resolve(editResult);
            this._resolve = null;
        }
    }
}
