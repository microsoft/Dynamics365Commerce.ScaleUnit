/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */

import { IExtensionViewControllerContext } from "PosApi/Create/Views";
import { Entities } from "../DataService/DataServiceEntities.g";
import * as Messages from "../DataService/DataServiceRequests.g";
import ExampleCreateDialog from "../Controls/Dialogs/Create/ExampleCreateDialogModule";
import ExampleEditDialog from "../Controls/Dialogs/Edit/ExampleEditDialogModule";
import PingResultDialog from "../Controls/Dialogs/Display/PingResultDialogModule";
import { ObjectExtensions, ArrayExtensions } from "PosApi/TypeExtensions";

/**
 * The ViewModel for ExampleView.
 */
export default class ExampleViewModel {
    public title: string;
    public loadedData: Entities.ExampleEntity[];
    public isItemSelected: () => boolean;
    private _selectedItem: Entities.ExampleEntity;
    private _context: IExtensionViewControllerContext;

    constructor(context: IExtensionViewControllerContext) {
        this._context = context;
        this.title = context.resources.getString("string_0001");
        this.loadedData = [];
        this.isItemSelected = () => !ObjectExtensions.isNullOrUndefined(this._selectedItem);
    }

    public load(): Promise<void> {
        return this._context.runtime
            .executeAsync(new Messages.BoundController.GetAllExampleEntitiesRequest())
            .then(response => {
                if (!response.canceled) {
                    this.loadedData = response.data.result;
                }
            });
    }

    /**
     * Handler for list item selection.
     * @param {Entities.ExampleEntity[]} items
     */
    public seletionChanged(items: Entities.ExampleEntity[]): Promise<void> {
        this._context.logger.logInformational("Item selected:" + JSON.stringify(items));
        this._selectedItem = ArrayExtensions.firstOrUndefined(items);
        return Promise.resolve();
    }

    public createExampleEntity(): Promise<boolean> {
        let dialog: ExampleCreateDialog = new ExampleCreateDialog();
        return dialog
            .open()
            .then(newItem => {
                // No action if the dialog was canceled
                if (ObjectExtensions.isNullOrUndefined(newItem)) {
                    this._context.logger.logInformational("Create canceled.");
                    return Promise.resolve(false);;
                }

                this._context.logger.logInformational("Item created with data: " + JSON.stringify(newItem));
                // Create the entity and reload the loaded data to reflect the change:
                return this._context.runtime
                    .executeAsync(new Messages.BoundController.CreateExampleEntityRequest(newItem))
                    .then(response => {
                        if (!response.canceled && response.data.result != 0) {
                            this._context.logger.logInformational("Create success for id: " + response.data.result);
                            return this.load().then((): boolean => true); // Load the updated data
                        }
                        this._context.logger.logInformational("Create failed for entity: " + JSON.stringify(newItem));
                        return Promise.resolve(false);
                    });
            }).catch(reason => {
                this._context.logger.logError("Error occurred in the create dialog: " + JSON.stringify(reason));
                return Promise.resolve(false);;
            });
    }

    public editExampleEntity(): Promise<boolean> {
        let dialog: ExampleEditDialog = new ExampleEditDialog();
        return dialog
            .open(this._selectedItem)
            .then(updatedItem => {
                // No action if the dialog was canceled
                if (ObjectExtensions.isNullOrUndefined(updatedItem)) {
                    this._context.logger.logInformational("Update canceled for data: " + JSON.stringify(updatedItem));
                    return Promise.resolve(false);
                }

                this._context.logger.logInformational("Updated data is: " + JSON.stringify(updatedItem));
                // Perform the update and reload the loaded data to reflect the change:
                return this._context.runtime
                    .executeAsync(new Messages.BoundController.UpdateExampleEntityRequest(updatedItem.UnusualEntityId, updatedItem))
                    .then(response => {
                        if (!response.canceled && response.data.result) {
                            this._context.logger.logInformational("Update success for id: " + updatedItem.UnusualEntityId);
                            return this.load().then((): boolean => true); // Load the updated data
                        }
                        this._context.logger.logInformational("Update failed for id: " + updatedItem.UnusualEntityId);
                        return Promise.resolve(false);
                    });
            }).catch(reason => {
                this._context.logger.logError("Error occurred in the edit dialog: " + JSON.stringify(reason));
                return Promise.resolve(false);
            });
    }

    public deleteExampleEntity(): Promise<void> {
        // Delete the selected entity and reload the loaded data to reflect the change:
        return this._context.runtime
            .executeAsync(new Messages.BoundController.DeleteExampleEntityRequest(this._selectedItem.UnusualEntityId))
            .then(response => {
                if (!response.canceled && response.data.result) {
                    this._context.logger.logInformational("Delete success for id: " + this._selectedItem.UnusualEntityId);
                    return this.load(); // Load the updated data
                }
                this._context.logger.logInformational("Delete failed for id " + this._selectedItem.UnusualEntityId);
                return Promise.resolve();
            });
    }

    public runPingTest(): Promise<void> {
        return this._context.runtime
            .executeAsync(new Messages.StoreOperations.SimplePingGetRequest())
            .then(pingGetResponse => {
                return this._context.runtime
                    .executeAsync(new Messages.StoreOperations.SimplePingPostRequest())
                    .then(pingPostResponse => {
                        let pingResultDialog: PingResultDialog = new PingResultDialog();
                        return pingResultDialog.open(pingGetResponse.data.result, pingPostResponse.data.result);
                    });
            });
    }
}
