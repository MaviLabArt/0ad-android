/**
 * This page allows to mix color using sliders one for each of three channels in range of 0 to 255 with
 * step of 1, returning sanitized color when closing
 */

const labels = [translate("Red"), translate("Green"), translate("Blue")];
const captions = [translate("Cancel"), translate("Save")];

function resizeChanel(i)
{
	const object0 = Engine.GetGUIObjectByName("color[0]");
	const height0 = object0.size.bottom - object0.size.top;
	const object = Engine.GetGUIObjectByName("color[" + i + "]");

	object.size.top = i * height0;
	object.size.bottom = (i + 1) * height0;
}

function initializeButtons()
{
	const button = [];
	const prom = setButtonCaptionsAndVisibility(button, captions,
		Engine.GetGUIObjectByName("cancelHotkey"), "cmButton");
	distributeButtonsHorizontally(button, captions);
	return prom;
}

/**
 * @param {String} initialColor - initial color as RGB string e.g. 100 0 200
 */
export async function init(initialColor)
{
	Engine.GetGUIObjectByName("titleBar").caption = translate("Color");
	Engine.GetGUIObjectByName("infoLabel").caption =
		translate("Move the sliders to change the Red, Green and Blue components of the Color");

	const chanels = [];
	const closePromise = initializeButtons();

	const currentColor = () => chanels.map(chanel => chanel.color).join(" ");
	const updateColorPreview = () => {
		const colorDisplay = Engine.GetGUIObjectByName("colorDisplay");
		colorDisplay.sprite = "color:" + currentColor();
	};

	const updateFromSlider = chanel => {
		chanel.color = Math.floor(chanel.slider.value);
		chanel.valueText.caption = chanel.color;
		updateColorPreview();
	};

	const c = initialColor.split(" ");

	for (let i = 0; i < labels.length; i++)
	{
		const color = Math.floor(+c[i] || 0);
		resizeChanel(i);

		const slider = Engine.GetGUIObjectByName("colorSlider[" + i + "]");
		slider.min_value = 0;
		slider.max_value = 255;
		slider.value = color;
		slider.onValueChange = () => { updateFromSlider(chanels[i]); };

		const valueText = Engine.GetGUIObjectByName("colorValue[" + i + "]");
		valueText.caption = color;

		chanels.push({
			"slider": slider,
			"color": color,
			"valueText": valueText
		});

		Engine.GetGUIObjectByName("colorLabel[" + i + "]").caption = labels[i];
	}

	updateColorPreview();
	// Update return color on cancel to prevent malformed values from initial input.
	const sanitizedColor = currentColor();

	return await closePromise === 0 ? sanitizedColor : currentColor();
}
